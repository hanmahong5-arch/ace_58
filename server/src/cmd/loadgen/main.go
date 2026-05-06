// Package main 实现 cmd/loadgen —— AION 5.8 协议级压测工具。
//
// 设计理念：
//
//  1. **协议层零重写**：直接 import internal/crypto + internal/aionproto，
//     与 server 走完全一致的 BF-LE / RSA-NoPad / XOR(seed=1234) 链。
//  2. **复用 tinyclient phase 流程**（git HEAD 状态副本，working tree 由另一
//     会话改动中），但把 phase 提炼成 Scenario 对象，每个 worker 一份独立
//     状态，无共享。
//  3. **Ramp-up 而非雷击**：用 golang.org/x/time/rate 限流，concurrency 在
//     rampDuration 内线性达到目标——能在 grafana 观察到"哪个并发数 p99
//     开始劣化"。
//  4. **自有 prom registry @ :9091**：不复用 world 的 :9090，端口隔离。
//
// 用法（典型）：
//
//	loadgen \
//	  -target=127.0.0.1:2208 \
//	  -game-port=7877 \
//	  -concurrency=500 \
//	  -ramp=60s \
//	  -duration=5m \
//	  -metrics-addr=127.0.0.1:9091
//
// 退出条件：
//   - duration 到点：clean cancel 所有 worker，等 30s 让 in-flight session
//     收尾，然后 print summary 并 exit 0。
//   - SIGINT/SIGTERM：同上 graceful。
//   - 任何 worker panic：记录到 stderr，不影响其他 worker（recover 兜底）。
package main

import (
	"context"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/time/rate"
)

func main() {
	target := flag.String("target", "127.0.0.1:2208", "auth gateway host:port (dev=2208, prod=2108)")
	gamePort := flag.Int("game-port", 7877, "game gateway port (dev=7877, prod=7777)")
	concurrency := flag.Int("concurrency", 100, "稳态并发 worker 数")
	rampDur := flag.Duration("ramp", 30*time.Second, "ramp-up 持续时间（0 = 雷击启动，慎用）")
	duration := flag.Duration("duration", 2*time.Minute, "压测总时长")
	metricsAddr := flag.String("metrics-addr", "127.0.0.1:9091", "Prometheus /metrics 监听地址")
	password := flag.String("password", "hunter2", "压测账号统一密码")
	serverID := flag.Uint("server-id", uint(defaultServerID), "logical server selection")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	host, authPortStr, err := net.SplitHostPort(*target)
	if err != nil {
		logger.Error("invalid -target", "err", err)
		os.Exit(2)
	}
	authPort, err := strconv.Atoi(authPortStr)
	if err != nil {
		logger.Error("invalid -target port", "err", err)
		os.Exit(2)
	}

	metrics := NewMetrics()

	// 启动 :9091 metrics server（独立 registry）。listener 错误立即上报但
	// 不阻塞主流程——压测核心是产生负载，metrics 是辅助。
	stopMetrics := startMetricsServer(*metricsAddr, metrics, logger)
	defer stopMetrics()

	ctx, cancel := signalContext(*duration)
	defer cancel()

	rateSec := RampSchedule(*concurrency, *rampDur)
	limiter := NewRampLimiter(rateSec)
	logger.Info("loadgen: starting",
		"target", *target, "game_port", *gamePort,
		"concurrency", *concurrency, "ramp", *rampDur,
		"duration", *duration, "metrics", *metricsAddr,
		"rate_per_sec", rateSec)

	t0 := time.Now()

	var wg sync.WaitGroup
	for i := 0; i < *concurrency; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			runWorker(ctx, id, host, authPort, *gamePort, *password, uint32(*serverID), limiter, metrics, logger)
		}(i)
	}
	wg.Wait()

	logger.Info("loadgen: done", "elapsed", time.Since(t0))
}

// runWorker 是单个 worker 的主循环：拿令牌 → 跑一次 Scenario → 拿下一个令牌。
func runWorker(
	ctx context.Context,
	id int,
	host string, authPort, gamePort int,
	password string, serverID uint32,
	lim *rate.Limiter,
	m *LoadgenMetrics,
	logger *slog.Logger,
) {
	for {
		if err := lim.Wait(ctx); err != nil {
			return // ctx cancel
		}

		// 每次会话用全新 randName 账号，避免 1000 并发撞同名（alphabet 32 × 12 = ~10^18 空间）。
		account := randName("lg_", 12)

		m.SessionsStarted.Inc()
		m.ActiveSessions.Inc()
		// 用 closure + recover 兜底单 worker panic，避免 1 个 worker 把整轮压测拉崩。
		runErr := safeRun(func() error {
			s := NewScenario(host, authPort, gamePort, account, password, serverID, m)
			defer s.Close()
			return s.Run()
		})
		m.ActiveSessions.Dec()
		if runErr != nil {
			m.SessionsFailed.Inc()
			logger.Debug("scenario failed", "worker", id, "account", account, "err", runErr)
		} else {
			m.SessionsSuccess.Inc()
		}
	}
}

// safeRun 把 fn 包在 defer-recover 里：recover 捕获后转 error 返回。
// 这样单 worker 的 nil pointer / index oob 不会带挂整个 loadgen 进程。
func safeRun(fn func() error) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic: %v", r)
		}
	}()
	return fn()
}

// signalContext 返回 (a) duration 到期或 (b) SIGINT/SIGTERM 时 cancel 的 ctx。
func signalContext(duration time.Duration) (context.Context, context.CancelFunc) {
	parent := context.Background()
	if duration > 0 {
		var cancel context.CancelFunc
		parent, cancel = context.WithTimeout(parent, duration)
		// 包一层 signal handler，duration cancel 仍要执行。
		ctx, sigCancel := context.WithCancel(parent)
		ch := make(chan os.Signal, 1)
		signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
		go func() {
			select {
			case <-ch:
				sigCancel()
			case <-parent.Done():
			}
		}()
		return ctx, func() {
			signal.Stop(ch)
			sigCancel()
			cancel()
		}
	}
	ctx, cancel := context.WithCancel(parent)
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-ch
		cancel()
	}()
	return ctx, func() { signal.Stop(ch); cancel() }
}

// startMetricsServer 起一个独立 :9091 /metrics + /healthz HTTP 服务。
// 返回 stopFn，main defer 调用以 graceful shutdown。
func startMetricsServer(addr string, m *LoadgenMetrics, logger *slog.Logger) func() {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.HandlerFor(m.Registry, promhttp.HandlerOpts{
		EnableOpenMetrics: true,
	}))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte("ok\n"))
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Warn("metrics server died", "err", err)
		}
	}()

	return func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	}
}
