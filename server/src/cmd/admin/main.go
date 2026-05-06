// Package main is the entry point for the Admin API service.
//
// REST API + Web dashboard for GM operations, player management,
// server monitoring. Replaces NCSoft's ASP.NET GM tool.
//
// 架构（W1 swarm 实装；R5+ 升 PG admin_users）：
//   - chi v5 路由 + JWT v5 鉴权 + 自写 token-bucket RateLimit
//   - 用户库走 PG admin_users 表（bcrypt cost=12），dev 可用 AION_ADMIN_DEV_FALLBACK=1 回退 in-memory
//   - 仅监听 127.0.0.1（绝不直暴露公网，外网走反代+TLS）
//   - JWT secret 走环境变量 AION_ADMIN_JWT_SECRET，启动期校验长度 ≥32B
//   - middleware 顺序：Recoverer → RequestID → Logger → CORS → RateLimit → Auth → handler
//
// 运行（生产姿态 — 需要 PG + admin_users 表已 migrate）：
//
//	export AION_ADMIN_JWT_SECRET="$(openssl rand -hex 32)"     # 64 hex = 32B
//	export AION_ADMIN_PG_DSN="postgres://aion:aion@127.0.0.1:5432/aion_world_live?sslmode=disable"
//	./admin
//
// 运行（dev 姿态 — in-memory 三角色）：
//
//	export AION_ADMIN_JWT_SECRET="..."
//	export AION_ADMIN_DEV_FALLBACK=1
//	./admin
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/time/rate"
)

// listenAddr 是 admin 监听地址；硬绑 127.0.0.1 拒绝外网直连。
const listenAddr = "127.0.0.1:8080"

// wireUserStore 选择 PG 实现（生产姿态）或 memory 实现（仅 AION_ADMIN_DEV_FALLBACK=1）。
//
// 决策表：
//
//	PG_DSN 设了                   → pgUserStore（不论 DEV_FALLBACK 是否设置）
//	PG_DSN 未设 + DEV_FALLBACK=1  → memUserStore
//	PG_DSN 未设 + DEV_FALLBACK!=1 → fatal error（拒绝裸跑）
//
// 返回的 close 在进程退出时调用，关闭 pgxpool；mem 实现下是 no-op。
func wireUserStore(ctx context.Context, logger *slog.Logger) (userStore, func(), error) {
	dsn := os.Getenv(envPGDSN)
	if dsn != "" {
		// 生产姿态 — 启动期失败 fatal。
		pool, err := pgxpool.New(ctx, dsn)
		if err != nil {
			return nil, nil, err
		}
		if err := pool.Ping(ctx); err != nil {
			pool.Close()
			return nil, nil, err
		}
		logger.Info("admin: 用户库后端 = PG admin_users")
		return newPGUserStore(pool, logger), pool.Close, nil
	}
	if os.Getenv(envDevFallback) != "1" {
		return nil, nil, errors.New("admin: " + envPGDSN + " 未设置且 " + envDevFallback + "!=1 — 拒绝以裸 in-memory 用户库启动")
	}
	logger.Warn("admin: 用户库后端 = in-memory dev fallback (生产环境必须改 AION_ADMIN_PG_DSN)")
	return defaultUsers(), func() {}, nil
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	bootCtx, bootCancel := context.WithTimeout(context.Background(), 10*time.Second)
	store, closeStore, err := wireUserStore(bootCtx, logger)
	bootCancel()
	if err != nil {
		// 启动期硬错：用户库后端不可达就 fatal，远胜于"运行期偶发 401"误诊。
		logger.Error("admin: 用户库初始化失败", "err", err)
		os.Exit(1)
	}
	defer closeStore()

	auth, err := loadAuthStoreWithStore(store)
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
