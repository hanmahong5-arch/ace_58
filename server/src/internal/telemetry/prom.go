// Package telemetry exposes Prometheus metrics + an embeddable HTTP server
// for AionCore 5.8 services (gateway / world / chat / logd / admin).
//
// Design goals:
//   - **No global state.** Every caller creates a fresh prometheus.Registry
//     so unit tests stay hermetic and multi-process embedding stays clean.
//   - **Library, not framework.** This package only hands back a Registry,
//     a Metrics struct, and an HTTP server runner. Wiring metrics into the
//     hot path (player-enter, SP-call, packet-recv) is the caller's job —
//     see doc/observability.md for integration recipes.
//   - **Fail-soft on shutdown.** RunServer respects ctx cancellation and
//     uses a 5-second graceful Shutdown; it never blocks the parent forever.
package telemetry

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// shutdownTimeout caps how long server.Shutdown() waits for in-flight
// /metrics scrapes to drain before forcing the listener closed.
const shutdownTimeout = 5 * time.Second

// NewRegistry returns a fresh Prometheus registry.
//
// Each AionCore process should own exactly ONE registry — typically created
// in main(), passed to telemetry.New(reg) for collector registration, and
// then to RunServer(ctx, addr, reg, logger) for HTTP exposition.
//
// We intentionally avoid prometheus.DefaultRegisterer because:
//  1. tests may run many telemetry instances in parallel (shared global =
//     "duplicate metrics collector" panic);
//  2. multi-binary builds (gateway+world in one process for boot-test) would
//     otherwise pollute each other.
func NewRegistry() *prometheus.Registry {
	return prometheus.NewRegistry()
}

// Handler builds an http.Handler that serves the registry's metrics in the
// Prometheus text exposition format.
//
// The wrapper sets EnableOpenMetrics=true so newer scrapers (Prometheus 2.x +
// VictoriaMetrics) can opt into OpenMetrics features (exemplars, _created
// timestamps) when they negotiate the right Accept header.
func Handler(reg *prometheus.Registry) http.Handler {
	return promhttp.HandlerFor(reg, promhttp.HandlerOpts{
		// Surface scrape errors in HTTP body for easier diagnosis on staging
		// (Prometheus servers ignore non-200 anyway, so this is observability
		// bait, not a behavior change).
		ErrorHandling:     promhttp.ContinueOnError,
		EnableOpenMetrics: true,
	})
}

// RunServer starts a blocking HTTP server on addr that serves /metrics and
// /healthz, returning when ctx is cancelled or the listener fails.
//
// Endpoints:
//   - GET /metrics  → Prometheus text exposition (registry-bound)
//   - GET /healthz  → 200 OK with body "ok\n" (cheap liveness probe;
//     intentionally NOT registry-bound so it stays green even if a collector
//     panics — readiness should be checked elsewhere)
//
// Lifecycle:
//   - When ctx is cancelled, RunServer initiates server.Shutdown with a
//     5-second deadline. Any in-flight scrapes get to finish; new connections
//     are rejected. RunServer returns nil on clean shutdown.
//   - If the listener dies for any other reason (e.g., port collision), the
//     underlying error is returned. http.ErrServerClosed is treated as
//     success since it just means Shutdown() ran.
//
// Typical wiring (see doc/observability.md):
//
//	go func() {
//	    if err := telemetry.RunServer(ctx, ":9090", reg, logger); err != nil {
//	        logger.Error("metrics server died", "err", err)
//	    }
//	}()
func RunServer(ctx context.Context, addr string, reg *prometheus.Registry, logger *slog.Logger) error {
	if logger == nil {
		// Defensive default — a nil logger from a misconfigured caller
		// should not crash the metrics goroutine.
		logger = slog.Default()
	}

	mux := http.NewServeMux()
	mux.Handle("/metrics", Handler(reg))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		// Plain-text liveness; deliberately bypasses the registry so a
		// collector panic cannot mark the process unhealthy.
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})

	srv := &http.Server{
		Addr:    addr,
		Handler: mux,
		// Conservative timeouts; metrics scrapes are tiny and fast.
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	// Surface listener errors via a buffered channel so we can race them
	// against ctx.Done() without leaking goroutines.
	errCh := make(chan error, 1)
	go func() {
		logger.Info("telemetry: metrics server listening", "addr", addr)
		errCh <- srv.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		// Graceful shutdown — give in-flight scrapes 5s to drain.
		logger.Info("telemetry: shutting down metrics server", "addr", addr)
		shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			logger.Warn("telemetry: shutdown error", "err", err)
			return err
		}
		// Drain the goroutine's return value to avoid a goroutine leak.
		<-errCh
		return nil
	case err := <-errCh:
		// Server exited on its own — translate the canonical "closed"
		// sentinel into a nil success.
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}
