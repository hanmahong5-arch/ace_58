// router.go — 路由组装与端点 stub。
//
// 路由策略：
//   - 公开：/healthz、/metrics、/admin/login（带 IP 桶限速 5/min）
//   - 全部 /api/v1/* 走 auth + sub 桶限速（60/min）+ RBAC
//
// 端点 stub 都返结构化 JSON，含 note 字段标 "TODO: wire PG SP / NATS dispatch"，
// 让前端可先对接做联调，后端再补真实存储层。
package main

import (
	"context"
	"log/slog"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// routerDeps 是 newRouter 的依赖包；用结构体而非位置参数防参数顺序错位。
type routerDeps struct {
	auth        *authStore
	loginLimit  *rateLimiter // 登录端点 IP 桶（5/min）
	apiLimit    *rateLimiter // /api/v1/* sub 桶（60/min）
	logger      *slog.Logger
}

// newRouter 装配整棵路由树。
//
// 注意 chi 的 r.Group / r.With 用法：r.With(...) 返回一个新的 Router 不影响外层；
// r.Group 是收 mu 闭包，用于"一组共享 middleware 但路径不带前缀"。
func newRouter(deps routerDeps) http.Handler {
	r := chi.NewRouter()

	// 全局 middleware（顺序至关重要，见 middleware.go 注释）
	r.Use(middleware.Recoverer)
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(corsMiddleware)

	// 公开 — 不限速、不鉴权
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	r.Handle("/metrics", promhttp.Handler())

	// 登录端点：IP 桶限速 5/min（防暴力破解），不需要鉴权
	r.With(deps.loginLimit.middleware(keyByIP)).Post("/admin/login", deps.auth.handleLogin)

	// /api/v1/* — 全部要 JWT，按 sub 限速
	r.Route("/api/v1", func(api chi.Router) {
		api.Use(deps.apiLimit.middleware(keyBySubOrIP))
		api.Use(deps.auth.authMiddleware)

		// 玩家管理
		api.Route("/players", func(p chi.Router) {
			// 查询：gm + readonly
			p.With(requireRole(roleSuperadmin, roleGM, roleReadonly)).Get("/", listPlayers)
			p.With(requireRole(roleSuperadmin, roleGM, roleReadonly)).Get("/{id}", getPlayer)
			// 写操作：仅 superadmin + gm
			p.With(requireRole(roleSuperadmin, roleGM)).Post("/{id}/ban", banPlayer)
			p.With(requireRole(roleSuperadmin, roleGM)).Post("/{id}/kick", kickPlayer)
		})

		// 服务器监控
		api.With(requireRole(roleSuperadmin, roleGM, roleReadonly)).Get("/server/stats", serverStats)
	})

	return r
}

// listPlayers — GET /api/v1/players
//
// TODO: wire PG SP aion_ListOnlinePlayers / aion_ListAllPlayers。
func listPlayers(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"players": []any{},
		"total":   0,
		"note":    "TODO: wire PG SP aion_ListOnlinePlayers",
	})
}

// getPlayer — GET /api/v1/players/{id}
func getPlayer(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	writeJSON(w, http.StatusOK, map[string]any{
		"id":   id,
		"note": "TODO: wire PG SP aion_GetPlayerSummary",
	})
}

// banPlayer — POST /api/v1/players/{id}/ban
func banPlayer(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, _ := claimsFromCtx(r.Context())
	writeJSON(w, http.StatusAccepted, map[string]any{
		"id":     id,
		"by":     c.Subject,
		"action": "ban",
		"note":   "TODO: wire PG SP aion_BanAccount + NATS event admin.ban",
	})
}

// kickPlayer — POST /api/v1/players/{id}/kick
func kickPlayer(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	c, _ := claimsFromCtx(r.Context())
	writeJSON(w, http.StatusAccepted, map[string]any{
		"id":     id,
		"by":     c.Subject,
		"action": "kick",
		"note":   "TODO: wire NATS dispatch gateway.kick",
	})
}

// serverStats — GET /api/v1/server/stats
//
// 真实指标走 /metrics（prometheus 格式）；这里给个 quick view JSON 给 dashboard 用。
func serverStats(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"online":     0,
		"uptime_sec": 0,
		"note":       "TODO: read prom registry counters / read aion_GetServerSnapshot",
	})
}

// 编译期防呆：context 包必须被引用（避免未来重构丢 import）。
var _ = context.Background
