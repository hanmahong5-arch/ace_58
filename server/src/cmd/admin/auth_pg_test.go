// auth_pg_test.go — admin_users PG 后端集成测试 (env-gated)。
//
// 仅当 AION_TEST_PG_HOST / DB / USER / PASS 全部设置时才运行；缺一个就 Skip。
// 这与 internal/database/sp_pve_test.go 保持同模式 — `go test ./...` 在无 PG 的
// contributor box 上保持静默。
//
// 跑法（CI 模式 — service container）：
//
//	export AION_TEST_PG_HOST=127.0.0.1
//	export AION_TEST_PG_DB=aion_world_live
//	export AION_TEST_PG_USER=postgres
//	export AION_TEST_PG_PASS=postgres
//	cd server/src
//	go test -count=1 -run TestAdminUsersPG -v ./cmd/admin
//
// 这些测试覆盖：
//  1. seed superadmin 存在且默认密码可登录
//  2. 错密码拒绝（同 401 返 errInvalidCredentials）
//  3. disabled 账号拒绝
//  4. 未知 login 拒绝
//  5. recordLogin 写入 last_login 时间戳
//  6. bcrypt cost 验证（写入数据 = 12）
//  7. 端到端 HTTP /admin/login 走 pg store 成功
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
	"golang.org/x/time/rate"

	"aion58/internal/database"
)

// randSuffix 生成 n 字符 lowercase hex 后缀，用于 admin_users.login 命名空间隔离。
//
// 不用 testing.T.Name() 是因为 t.Name() 通常 30+ 字符，超过 admin_users.login
// 的 32 字符 CHECK；把它拍平成短随机量保证 prefix + suffix ≤ 32。
func randSuffix(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		// rand.Read 在合法输入下不会失败；崩了就 panic 让测试 fail-fast。
		panic(err)
	}
	return hex.EncodeToString(b)[:n]
}

// pgTestDSN 拼接同 internal/database/migrate_test.go 的 testDSN()，
// 但本包不能 import _test 文件，所以本地复制一份小逻辑（5 行）。
func pgTestDSN() (string, string) {
	host := os.Getenv("AION_TEST_PG_HOST")
	if host == "" {
		return "", "AION_TEST_PG_HOST not set"
	}
	db := os.Getenv("AION_TEST_PG_DB")
	if db == "" {
		return "", "AION_TEST_PG_DB not set"
	}
	user := os.Getenv("AION_TEST_PG_USER")
	if user == "" {
		return "", "AION_TEST_PG_USER not set"
	}
	if _, ok := os.LookupEnv("AION_TEST_PG_PASS"); !ok {
		return "", "AION_TEST_PG_PASS not set"
	}
	pass := os.Getenv("AION_TEST_PG_PASS")
	port := 5432
	if s := os.Getenv("AION_TEST_PG_PORT"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			port = n
		}
	}
	return fmt.Sprintf(
		"host=%s port=%d dbname=%s user=%s password=%s sslmode=disable",
		host, port, db, user, pass,
	), ""
}

// adminPGFixture 装配测试夹具：migrate + pool + 隔离用 admin 账号。
//
// 每个测试用 t.Name() 派生一个唯一 login 前缀（test_<short_name>），
// 并在 cleanup 阶段批量 DELETE 防污染。我们 NOT touch 真 'sadmin' 默认行
// 让它的存在 / 可登录由独立 subtest 单独验。
type adminPGFixture struct {
	pool       *pgxpool.Pool
	store      *pgUserStore
	loginNS    string // 例 "auth_pg_test_AdminUsersPG_VerifySuccess_"
	createdLog []string
}

func newAdminPGFixture(t *testing.T, ctx context.Context) *adminPGFixture {
	t.Helper()

	dsn, reason := pgTestDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	if err := database.Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pgxpool: %v", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		t.Fatalf("ping: %v", err)
	}

	// 派生命名空间：用进程 PID + ns 计数防与并发测试冲突。
	// login 列受 32 字符 CHECK 约束 — 必须保持 prefix + suffix 总长 ≤ 32。
	// 形如 "tp9999_a_alice"，prefix 8 + suffix ≤ 24 富余。
	ns := fmt.Sprintf("tp%d_%s_", os.Getpid()%10000, randSuffix(2))

	fx := &adminPGFixture{
		pool:    pool,
		store:   newPGUserStore(pool, nil),
		loginNS: ns,
	}

	// 测前清扫历史残留（同名 test 重跑 / -count 多轮）
	if _, err := pool.Exec(ctx, `DELETE FROM admin_users WHERE login LIKE $1`, ns+"%"); err != nil {
		pool.Close()
		t.Fatalf("pre-cleanup: %v", err)
	}

	t.Cleanup(func() {
		// 测后兜底清扫
		_, _ = pool.Exec(context.Background(), `DELETE FROM admin_users WHERE login LIKE $1`, ns+"%")
		pool.Close()
	})

	return fx
}

// addUser 直接 INSERT 一行 admin_users 用于测试 — bypass admin 业务路径，
// 因为 admin 没有 "create user" 端点 (ops 直接 UPDATE 表)。
func (f *adminPGFixture) addUser(t *testing.T, ctx context.Context, login, plaintext, role string, disabled bool) {
	t.Helper()
	hash, err := bcrypt.GenerateFromPassword([]byte(plaintext), adminBcryptCost)
	if err != nil {
		t.Fatalf("bcrypt: %v", err)
	}
	full := f.loginNS + login
	if _, err := f.pool.Exec(ctx,
		`INSERT INTO admin_users (login, pass_hash, role, disabled) VALUES ($1, $2, $3, $4)`,
		full, string(hash), role, disabled,
	); err != nil {
		t.Fatalf("seed admin_users (%s): %v", full, err)
	}
	f.createdLog = append(f.createdLog, full)
}

// TestAdminUsersPG_SeededSuperadminExists — 默认 'sadmin' 行通过 migration 存在并可登录。
//
// 这个 subtest 不归 fixture cleanup 管 — 我们检查的是 migration 写入的真实行。
func TestAdminUsersPG_SeededSuperadminExists(t *testing.T) {
	dsn, reason := pgTestDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := database.Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pgxpool: %v", err)
	}
	defer pool.Close()

	store := newPGUserStore(pool, nil)
	role, err := store.verify(ctx, "sadmin", "sadmin-dev-pwd")
	if err != nil {
		t.Fatalf("verify default sadmin: %v", err)
	}
	if role != roleSuperadmin {
		t.Errorf("seed role: got %s, want %s", role, roleSuperadmin)
	}
}

// TestAdminUsersPG_VerifySuccess — 显式新建账号，用正确密码登录。
func TestAdminUsersPG_VerifySuccess(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	fx.addUser(t, ctx, "alice", "alice-pwd-123", roleGM, false)

	role, err := fx.store.verify(ctx, fx.loginNS+"alice", "alice-pwd-123")
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if role != roleGM {
		t.Errorf("role: got %s, want %s", role, roleGM)
	}
}

// TestAdminUsersPG_VerifyWrongPassword — 错密码返 errInvalidCredentials。
func TestAdminUsersPG_VerifyWrongPassword(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	fx.addUser(t, ctx, "bob", "right-pwd", roleReadonly, false)

	_, err := fx.store.verify(ctx, fx.loginNS+"bob", "wrong-pwd")
	if err != errInvalidCredentials {
		t.Errorf("err: got %v, want errInvalidCredentials", err)
	}
}

// TestAdminUsersPG_VerifyDisabledRejected — disabled=true 即使密码对也拒绝。
func TestAdminUsersPG_VerifyDisabledRejected(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	fx.addUser(t, ctx, "carol", "pwd-but-disabled", roleGM, true)

	_, err := fx.store.verify(ctx, fx.loginNS+"carol", "pwd-but-disabled")
	if err != errInvalidCredentials {
		t.Errorf("disabled login: got %v, want errInvalidCredentials", err)
	}
}

// TestAdminUsersPG_VerifyUnknownLogin — 未注册 login 拒绝（同样 errInvalidCredentials 防枚举）。
func TestAdminUsersPG_VerifyUnknownLogin(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	_, err := fx.store.verify(ctx, fx.loginNS+"never_registered", "anything")
	if err != errInvalidCredentials {
		t.Errorf("unknown login: got %v, want errInvalidCredentials", err)
	}
}

// TestAdminUsersPG_RecordLogin — 登录后 last_login 写入。
func TestAdminUsersPG_RecordLogin(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	login := fx.loginNS + "dave"
	fx.addUser(t, ctx, "dave", "dave-pwd", roleGM, false)

	// 先验 last_login = NULL
	var lastBefore *time.Time
	if err := fx.pool.QueryRow(ctx,
		`SELECT last_login FROM admin_users WHERE login = $1`, login,
	).Scan(&lastBefore); err != nil {
		t.Fatalf("pre last_login: %v", err)
	}
	if lastBefore != nil {
		t.Errorf("last_login expected NULL before recordLogin, got %v", lastBefore)
	}

	// 同步调用（不走 go 协程，确保测试断言时已落盘）
	fx.store.recordLogin(ctx, login)

	var lastAfter *time.Time
	if err := fx.pool.QueryRow(ctx,
		`SELECT last_login FROM admin_users WHERE login = $1`, login,
	).Scan(&lastAfter); err != nil {
		t.Fatalf("post last_login: %v", err)
	}
	if lastAfter == nil {
		t.Fatal("last_login still NULL after recordLogin")
	}
	if delta := time.Since(*lastAfter).Abs(); delta > 10*time.Second {
		t.Errorf("last_login drift > 10s: %v (got %v, now %v)", delta, *lastAfter, time.Now().UTC())
	}
}

// TestAdminUsersPG_BcryptCost12 — 验证 admin_users 中 hash 的 bcrypt cost ≥ 12。
//
// 这个测试守护"暴力破解防御档不退化"的不变量；如果将来谁不小心把 cost 改回 10，
// CI 会立刻黄掉。
func TestAdminUsersPG_BcryptCost12(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	fx.addUser(t, ctx, "eve", "eve-pwd", roleSuperadmin, false)

	var hash string
	if err := fx.pool.QueryRow(ctx,
		`SELECT pass_hash FROM admin_users WHERE login = $1`, fx.loginNS+"eve",
	).Scan(&hash); err != nil {
		t.Fatalf("read hash: %v", err)
	}
	cost, err := bcrypt.Cost([]byte(hash))
	if err != nil {
		t.Fatalf("bcrypt.Cost: %v", err)
	}
	if cost < 12 {
		t.Errorf("bcrypt cost: got %d, want ≥ 12", cost)
	}
}

// TestAdminUsersPG_HTTPLogin_PGStore — 端到端 HTTP /admin/login 用 pgUserStore。
//
// 跑完整 router 链路（含 rate limit + JSON 编解码），确保 pg store 与 handleLogin 衔接正确。
func TestAdminUsersPG_HTTPLogin_PGStore(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	fx := newAdminPGFixture(t, ctx)

	fx.addUser(t, ctx, "mallory", "mallory-pwd-456", roleGM, false)
	login := fx.loginNS + "mallory"

	// 装一份测试用 authStore (PG store + 强密钥)
	t.Setenv(envJWTSecret, strings.Repeat("k", 32))
	auth, err := loadAuthStoreWithStore(fx.store)
	if err != nil {
		t.Fatalf("loadAuthStoreWithStore: %v", err)
	}

	// 起一个 router；rate limiter 大桶免干扰
	rlCtx, rlCancel := context.WithCancel(context.Background())
	t.Cleanup(rlCancel)
	loginLim := newRateLimiter(rlCtx, rate.Every(time.Millisecond), 1000)
	apiLim := newRateLimiter(rlCtx, rate.Every(time.Millisecond), 1000)
	h := newRouter(routerDeps{auth: auth, loginLimit: loginLim, apiLimit: apiLim})
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)

	body := fmt.Sprintf(`{"user":%q,"password":"mallory-pwd-456"}`, login)
	resp, err := http.Post(srv.URL+"/admin/login", "application/json", strings.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: got %d, want 200", resp.StatusCode)
	}
	var lr loginResponse
	if err := json.NewDecoder(resp.Body).Decode(&lr); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if lr.Role != roleGM {
		t.Errorf("role: got %s, want %s", lr.Role, roleGM)
	}
	if lr.Token == "" {
		t.Error("token empty")
	}
	// 确认 token 能被 parseToken 校验
	c, err := auth.parseToken(lr.Token)
	if err != nil {
		t.Fatalf("parseToken: %v", err)
	}
	if c.Subject != login || c.Role != roleGM {
		t.Errorf("claims: sub=%s role=%s", c.Subject, c.Role)
	}

	// 等 100ms 让 go store.recordLogin 写入 last_login (handleLogin 是 fire-and-forget)
	time.Sleep(150 * time.Millisecond)
	var stamped *time.Time
	if err := fx.pool.QueryRow(ctx,
		`SELECT last_login FROM admin_users WHERE login = $1`, login,
	).Scan(&stamped); err != nil {
		t.Fatalf("post last_login: %v", err)
	}
	if stamped == nil {
		t.Error("last_login should have been recorded by async handleLogin")
	}
}
