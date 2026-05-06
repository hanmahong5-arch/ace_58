// auth.go — JWT 签发 / 校验 + 用户库（接口抽象，pg/memory 双实现）
//
// WHY HS256：admin 进程独立部署，密钥只此一份，无需 RSA 公私分离的复杂度。
// HS256 + 32B 强密钥的攻击成本远超本场景威胁模型（≤10 GM、内网）。
//
// WHY HttpOnly cookie + body 双发：
//   - cookie HttpOnly 防 XSS 偷 token；
//   - body 同送 token 是为给纯 API 客户端（curl/前端 fetch with credentials:false）兜底。
//
// WHY 启动期 ≥32B 校验：HS256 密钥短于 hash 输出（256bit=32B）会被 HMAC 截断风险，
// 且暴力破解成本骤降。短密钥直接 fatal 比"运行时偶尔失败"更安全。
//
// 用户库（2026-05-06 R5+ 升级）：
//   - userStore 是接口；pgUserStore 走 admin_users 表（生产姿态），
//     memUserStore 走硬编码三角色（dev fallback）。
//   - main.go 决定哪种实现：AION_ADMIN_PG_DSN 设了走 pg；
//     未设 + AION_ADMIN_DEV_FALLBACK=1 才走 mem，否则启动期 fatal。
//   - bcrypt cost 升到 12（DefaultCost=10 已经偏弱；admin 是非热路径，
//     单次比较多花 ~150ms 玩家无感，但暴力破解算力翻 4×）。
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// envJWTSecret 是 HS256 密钥的环境变量名。
const envJWTSecret = "AION_ADMIN_JWT_SECRET"

// envPGDSN 是 admin_users 后端 PG DSN；未设 → 走 dev fallback（若开关打开）或 fatal。
const envPGDSN = "AION_ADMIN_PG_DSN"

// envDevFallback 是 dev escape hatch；未设 PG_DSN 且未设此开关 → 启动 fatal。
const envDevFallback = "AION_ADMIN_DEV_FALLBACK"

// jwtMinSecretBytes 是密钥最小长度（256 bit = HS256 hash 输出宽度）。
const jwtMinSecretBytes = 32

// tokenTTL 是 JWT 有效期；2h 平衡"无感续期"与"被盗损失窗口"。
const tokenTTL = 2 * time.Hour

// adminBcryptCost 是新建/校验密码的 bcrypt cost。
//
// DefaultCost=10 在 2026 已偏弱：M3 Macbook Pro 单次 ~75ms，
// 暴力破解成本仍可承受。12 是当前公认的"防爆破合格档"，单次 ~300ms，
// admin 登录是冷路径，玩家完全感知不到差异。
const adminBcryptCost = 12

// 三角色常量；硬编码在 router 端做 RBAC 比较。
const (
	roleSuperadmin = "superadmin"
	roleGM         = "gm"
	roleReadonly   = "readonly"
)

// ctxKey 是 context 注入的私有 key 类型，避免跨包碰撞。
type ctxKey int

const (
	ctxKeyClaims ctxKey = iota + 1
)

// adminClaims 是签进 JWT 的自定义 claim。
//
// jti 用 16B 随机十六进制；未来要做"主动撤销列表"时按 jti 黑名单。
type adminClaims struct {
	Role string `json:"role"`
	jwt.RegisteredClaims
}

// errInvalidCredentials 是 verify 失败的统一错误码。
//
// 不区分"用户不存在 / 密码错 / 账号 disabled" — 任意维度的细分都给暴力枚举者
// 提供副信道。call site 把它映射成 HTTP 401，对外只露 "invalid credentials"。
var errInvalidCredentials = errors.New("invalid credentials")

// userStore 抽象用户校验后端。memory 实现给 dev，pg 实现给生产。
//
// verify 在合法账号 + 合法密码时返回 role；任何其它情况返回 errInvalidCredentials
// （包括未知用户 / 密码错 / 账号 disabled）。
//
// recordLogin 在 verify 成功后记录登录时间；mem 实现是 no-op，pg 实现 UPDATE last_login。
// 失败 silent log 不阻断登录（last_login 是审计辅助字段，写不进不影响功能）。
type userStore interface {
	verify(ctx context.Context, login, password string) (role string, err error)
	recordLogin(ctx context.Context, login string)
}

// userRecord 是 memory 用户库的一行；passhash 由 bcrypt 生成。
type userRecord struct {
	passhash []byte
	role     string
}

// memUserStore 是硬编码用户库 — dev/test fallback。
type memUserStore struct {
	users map[string]userRecord
}

// verify 走 bcrypt 比较；timing 侧信道由 bcrypt 自身近似常数级覆盖。
func (m *memUserStore) verify(_ context.Context, login, password string) (string, error) {
	rec, ok := m.users[login]
	if !ok {
		// 仍调用一次 bcrypt 防 timing 枚举：未知用户的耗时应与已知用户错密相当。
		_ = bcrypt.CompareHashAndPassword([]byte("$2a$12$invalidhashinvalidhashinvalidhashinvalidhashinvalidha"), []byte(password))
		return "", errInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword(rec.passhash, []byte(password)); err != nil {
		return "", errInvalidCredentials
	}
	return rec.role, nil
}

// recordLogin — memory 版本无持久化，no-op。
func (m *memUserStore) recordLogin(_ context.Context, _ string) {}

// authStore 持有用户库 + JWT 密钥；通过依赖注入便于测试覆盖。
type authStore struct {
	users  userStore
	secret []byte
}

// loadAuthStore 是旧入口；保留作为 in-memory fallback 的快捷构造。
//
// 仅校验 JWT secret 长度 + 装一个 memory 用户库。生产 main.go 不调此函数，
// 而走 wireUserStore → loadAuthStoreWithStore 注入 PG 实现。
//
// 仍保留是因为 auth_test.go 等纯认证逻辑单测用它做 fixture，
// 不依赖 PG 既能跑（保持 `go test ./cmd/admin` 在无 PG 环境下绿）。
func loadAuthStore() (*authStore, error) {
	return loadAuthStoreWithStore(defaultUsers())
}

// loadAuthStoreWithStore 是新入口：调用方注入 store（pg or memory）。
//
// 仅校验 JWT secret 长度；store 的健康（PG 连接 / 表存在）由 store 构造方负责。
func loadAuthStoreWithStore(store userStore) (*authStore, error) {
	secret := []byte(os.Getenv(envJWTSecret))
	if len(secret) < jwtMinSecretBytes {
		return nil, fmt.Errorf("%s 长度 %dB < %dB（最小要求）", envJWTSecret, len(secret), jwtMinSecretBytes)
	}
	if store == nil {
		return nil, errors.New("loadAuthStoreWithStore: nil userStore")
	}
	return &authStore{
		users:  store,
		secret: secret,
	}, nil
}

// defaultUsers 提供三个硬编码账号 in-memory store；passhash 在进程启动期 bcrypt 一次。
//
// 返回 *memUserStore（直接实现 userStore 接口），调用方既可塞 authStore.users 字段
// 当作 dev fallback，也保持 auth_test.go 中 `users: defaultUsers()` 字段赋值的兼容。
//
// 默认密码（dev 用，部署前必须改 — 仅当 AION_ADMIN_DEV_FALLBACK=1 时才会被加载）：
//   - superadmin / sadmin-dev-pwd
//   - gm        / gm-dev-pwd
//   - readonly  / ro-dev-pwd
//
// 生产姿态下 admin_users PG 表是唯一真理源（见 sql/schema/00136_admin_users.sql）。
func defaultUsers() *memUserStore {
	mk := func(plain string) []byte {
		// cost=adminBcryptCost (12)，与 PG 表中存储的 hash 一致。
		h, err := bcrypt.GenerateFromPassword([]byte(plain), adminBcryptCost)
		if err != nil {
			// bcrypt 在合法输入下不会失败；走到这里说明运行时崩坏，直接 panic。
			panic(fmt.Sprintf("bcrypt: %v", err))
		}
		return h
	}
	return &memUserStore{users: map[string]userRecord{
		"superadmin": {passhash: mk("sadmin-dev-pwd"), role: roleSuperadmin},
		"gm":         {passhash: mk("gm-dev-pwd"), role: roleGM},
		"readonly":   {passhash: mk("ro-dev-pwd"), role: roleReadonly},
	}}
}

// signToken 给已认证用户签发 JWT。
func (s *authStore) signToken(sub, role string) (string, time.Time, error) {
	now := time.Now().UTC()
	exp := now.Add(tokenTTL)
	jtiBytes := make([]byte, 16)
	if _, err := rand.Read(jtiBytes); err != nil {
		return "", time.Time{}, err
	}
	claims := adminClaims{
		Role: role,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   sub,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(exp),
			ID:        hex.EncodeToString(jtiBytes),
			Issuer:    "aion-admin",
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString(s.secret)
	return signed, exp, err
}

// parseToken 校验签名 + exp + 算法白名单，返回 claims。
func (s *authStore) parseToken(raw string) (*adminClaims, error) {
	tok, err := jwt.ParseWithClaims(raw, &adminClaims{}, func(t *jwt.Token) (any, error) {
		// 算法白名单：只信 HS256，防"alg=none"/"alg=RS256 公钥当 HMAC"两类经典攻击。
		if t.Method.Alg() != jwt.SigningMethodHS256.Alg() {
			return nil, fmt.Errorf("unexpected alg: %s", t.Method.Alg())
		}
		return s.secret, nil
	})
	if err != nil {
		return nil, err
	}
	c, ok := tok.Claims.(*adminClaims)
	if !ok || !tok.Valid {
		return nil, errors.New("invalid token")
	}
	return c, nil
}

// loginRequest 是 POST /admin/login 的请求体。
type loginRequest struct {
	User     string `json:"user"`
	Password string `json:"password"`
}

// loginResponse 是登录成功的响应；token 同时通过 Set-Cookie 下发。
type loginResponse struct {
	Token     string `json:"token"`
	ExpiresAt int64  `json:"expires_at"` // unix epoch (s)
	Role      string `json:"role"`
}

// handleLogin 处理 POST /admin/login。
//
// 失败 401 不区分"用户不存在/密码错/账号 disabled"以减少枚举。verify 内部
// 走 bcrypt 比较，timing 侧信道由 bcrypt 自身近似常数级覆盖。
func (s *authStore) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	role, err := s.users.verify(r.Context(), req.User, req.Password)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid credentials"})
		return
	}
	// 异步记录登录时间 — 失败不阻塞登录响应。
	// 拷贝 user 防 race (req 是栈上 struct，但 closure 捕获更安全)。
	go s.users.recordLogin(context.Background(), req.User)

	tok, exp, err := s.signToken(req.User, role)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "sign failed"})
		return
	}
	// HttpOnly 防 XSS 偷 token；Secure 在内网 dev 不强制，生产由反代层补。
	http.SetCookie(w, &http.Cookie{
		Name:     "aion_admin_token",
		Value:    tok,
		Path:     "/",
		Expires:  exp,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	})
	writeJSON(w, http.StatusOK, loginResponse{Token: tok, ExpiresAt: exp.Unix(), Role: role})
}

// authMiddleware 校验 Bearer JWT，把 claims 注入 context。
//
// 优先 Authorization header；再回退到 cookie，方便浏览器直接调 API。
func (s *authStore) authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := extractBearer(r)
		if raw == "" {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "missing token"})
			return
		}
		claims, err := s.parseToken(raw)
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid token"})
			return
		}
		ctx := context.WithValue(r.Context(), ctxKeyClaims, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// extractBearer 优先从 Authorization 头读 Bearer，再回退 cookie。
func extractBearer(r *http.Request) string {
	if h := r.Header.Get("Authorization"); h != "" {
		const prefix = "Bearer "
		if strings.HasPrefix(h, prefix) {
			return strings.TrimSpace(h[len(prefix):])
		}
	}
	if c, err := r.Cookie("aion_admin_token"); err == nil {
		return c.Value
	}
	return ""
}

// claimsFromCtx 从 context 取出已校验的 claims；handler 拿不到就是 middleware 没串好。
func claimsFromCtx(ctx context.Context) (*adminClaims, bool) {
	c, ok := ctx.Value(ctxKeyClaims).(*adminClaims)
	return c, ok
}

// writeJSON 是统一的 JSON 响应工具；忽略 Encode 错误（连接已断的话写不进也无所谓）。
func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
