// Package main is the entry point for the Admin API service.
//
// REST API + Web dashboard for GM operations, player management,
// server monitoring. Replaces NCSoft's ASP.NET GM tool.
//
// 架构（W1 swarm 实装）：
//   - chi v5 路由 + JWT v5 鉴权 + 自写 token-bucket RateLimit
//   - 三角色硬编码（superadmin/gm/readonly），TODO 迁 PG admin_users
//   - 仅监听 127.0.0.1（绝不直暴露公网，外网走反代+TLS）
//   - JWT secret 走环境变量 AION_ADMIN_JWT_SECRET，启动期校验长度 ≥32B
//   - middleware 顺序：Recoverer → RequestID → Logger → CORS → RateLimit → Auth → handler
//
// 运行：
//
//	export AION_ADMIN_JWT_SECRET="$(openssl rand -hex 32)"   # 64 hex = 32B
//	./admin
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/time/rate"
)

// listenAddr 是 admin 监听地址；硬绑 127.0.0.1 拒绝外网直连。
const listenAddr = "127.0.0.1:8080"

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	auth, err := loadAuthStore()
	if err != nil {
		// 启动期硬错：JWT 密钥配错就 fatal，远胜于"运行期偶发 401"误诊。
		logger.Error("admin: 鉴权初始化失败", "err", err)
		os.Exit(1)
	}

	// rate limiter 的 ctx 与进程 ctx 一致；进程退出时 GC goroutine 自动收线。
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// 登录桶：每 IP 每分钟 5 次（暴力破解防御档），burst=5 允许偶发并发尝试。
	loginLim := newRateLimiter(ctx, rate.Every(time.Minute/5), 5)
	// API 桶：每 sub 每秒 1 次，burst=60 — 1 分钟内允许 60 次突发后回到 1Hz 稳态。
	apiLim := newRateLimiter(ctx, rate.Every(time.Second), 60)

	handler := newRouter(routerDeps{
		auth:       auth,
		loginLimit: loginLim,
		apiLimit:   apiLim,
		logger:     logger,
	})

	srv := &http.Server{
		Addr:              listenAddr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		logger.Info("admin: REST listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("admin: ListenAndServe", "err", err)
		}
	}()

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch

	logger.Info("admin: shutting down")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	_ = srv.Shutdown(shutdownCtx)
}
