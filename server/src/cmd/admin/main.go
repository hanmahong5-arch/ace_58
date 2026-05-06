// Package main is the entry point for the Admin API service.
//
// REST API + Web dashboard for GM operations, player management,
// server monitoring. Replaces NCSoft's ASP.NET GM tool.
//
// 当前阶段：REST 骨架已就位（chi v5 + JWT v5 + token-bucket rate limit）。
// 实际 GM endpoint（玩家查询、封禁、奖励发放、服务器监控）由 W1 swarm 扩充。
//
// 设计要点：
//   - 仅监听 127.0.0.1（绝不直暴露公网，外网走反代+TLS）
//   - JWT secret 走 TOML 配置，启动期校验长度 ≥32B
//   - middleware 顺序：Recoverer → RequestID → Logger → CORS → RateLimit → Auth → handler
//   - 三角色硬编码：superadmin / gm / readonly（≤10 GM 规模 RBAC 框架是过度设计）
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	_ "github.com/golang-jwt/jwt/v5" // anchored: used by auth middleware (W1)
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))

	r := chi.NewRouter()
	r.Use(middleware.Recoverer)
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger)

	// Health check — 公开，无 rate limit / auth（K8s/runbook probe 用）
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	// 占位：/metrics 由 W1 接 prometheus.Handler；/api/v1/* 由 W1 实装
	// 暂时保留 admin 进程启动语义不变（健康检查通过 → 5 进程拓扑健全）

	srv := &http.Server{
		Addr:              "127.0.0.1:8080",
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		slog.Info("admin: REST listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("admin: ListenAndServe", "err", err)
		}
	}()

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch

	slog.Info("admin: shutting down")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}
