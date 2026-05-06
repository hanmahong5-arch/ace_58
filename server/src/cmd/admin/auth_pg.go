// auth_pg.go — admin_users PG 后端实现 (生产姿态)。
//
// 设计：
//   - 单表 admin_users (login PK, pass_hash, role, disabled, last_login)，
//     不走 SP — 因为这只是简单 SELECT/UPDATE，加 SP 包装反而增加 admin 团队
//     运维表的难度（每次加角色要改 SP）。
//   - verify 一次性 SELECT pass_hash, role, disabled — 三字段联取，
//     avoid 多次 round-trip。disabled 在 SELECT 后判，仍走 bcrypt 比较防 timing。
//   - recordLogin 异步触发，单条 UPDATE，失败 silent log（last_login 是审计辅助）。
//   - 不维护本地缓存 — admin 团队 ≤10 人，登录是冷路径，PG 一次往返 <1ms 性价比最优。
//
// 命名约定 (见根 CLAUDE.md "Java/Spring" 节但同样适用 PG 客户端)：
//   - 标识符必须双引号；但本表 / 列名都是裸 lower-case 形式，pgx 默认行为正确。
//   - 严禁在此处 INSERT/UPDATE/DELETE user_data / user_item — 那些必须走 1314 SP。
//     admin_users 是新表，不属于 NCSoft 1314 SP 体系，直接 SQL 是合规设计。
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// pgUserStore 走 admin_users 表做密码校验 + 登录记录。
type pgUserStore struct {
	pool   *pgxpool.Pool
	logger *slog.Logger
}

// newPGUserStore 构造一个 PG 后端 store。
//
// 入参 logger 可为 nil（fallback 到 slog.Default）。
func newPGUserStore(pool *pgxpool.Pool, logger *slog.Logger) *pgUserStore {
	if logger == nil {
		logger = slog.Default()
	}
	return &pgUserStore{pool: pool, logger: logger}
}

// verify 校验登录密码，返回 role 或 errInvalidCredentials。
//
// 401 等价的失败维度：
//  1. login 不存在
//  2. disabled = true（admin 已停用）
//  3. bcrypt 比较失败
//
// 三类都返 errInvalidCredentials 防枚举（见 errInvalidCredentials 注释）。
// 真错（PG 不可达 / 行损坏）才返底层 error。
func (s *pgUserStore) verify(ctx context.Context, login, password string) (string, error) {
	var (
		passHash string
		role     string
		disabled bool
	)
	err := s.pool.QueryRow(ctx,
		`SELECT pass_hash, role, disabled FROM admin_users WHERE login = $1`,
		login,
	).Scan(&passHash, &role, &disabled)
	if errors.Is(err, pgx.ErrNoRows) {
		// 未知用户 — 仍跑一次 bcrypt 防 timing 侧信道枚举。
		_ = bcrypt.CompareHashAndPassword([]byte("$2a$12$invalidhashinvalidhashinvalidhashinvalidhashinvalidha"), []byte(password))
		return "", errInvalidCredentials
	}
	if err != nil {
		return "", fmt.Errorf("admin_users select: %w", err)
	}
	if disabled {
		// disabled — 仍跑一次 bcrypt 比较保持耗时一致。
		_ = bcrypt.CompareHashAndPassword([]byte(passHash), []byte(password))
		return "", errInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(passHash), []byte(password)); err != nil {
		return "", errInvalidCredentials
	}
	return role, nil
}

// recordLogin 在 verify 成功后写 last_login。
//
// 失败 silent log — 写不进 last_login 不应阻塞登录响应。
// 调用方应 `go store.recordLogin(...)` 异步触发。
func (s *pgUserStore) recordLogin(ctx context.Context, login string) {
	_, err := s.pool.Exec(ctx,
		`UPDATE admin_users SET last_login = now() WHERE login = $1`,
		login,
	)
	if err != nil {
		// last_login 是审计辅助，写失败时不阻塞主流程，只记录。
		s.logger.Warn("admin: recordLogin failed", "login", login, "err", err)
	}
}
