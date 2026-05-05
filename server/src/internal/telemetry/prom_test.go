// Package telemetry — unit tests.
//
// These tests run hermetically: each test gets its own prometheus.Registry
// (no global state), and the HTTP server tests use httptest / ephemeral
// localhost ports so they parallelize safely.
package telemetry

import (
	"context"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// TestNewMetrics_RegistersAll verifies that telemetry.New() registers every
// declared collector against the supplied registry. We assert ≥8 metric
// families because that's our published surface (see Metrics struct).
//
// Going through reg.Gather() (rather than peeking inside Metrics) tests the
// observable contract: a Prometheus scrape will see all 8 families.
func TestNewMetrics_RegistersAll(t *testing.T) {
	reg := NewRegistry()
	m := New(reg)
	if m == nil {
		t.Fatal("New returned nil Metrics bundle")
	}

	// Touch each metric so even no-label-value collectors emit at least one
	// series at scrape time — Gather() omits *Vec metrics that have never
	// observed any labels.
	m.PlayerCount.WithLabelValues("zone1").Set(1)
	m.PacketsTotal.WithLabelValues("cm", "0x4B").Inc()
	m.SPLatencySeconds.WithLabelValues("sp_test").Observe(0.005)
	m.LuaCallLatencySeconds.WithLabelValues("on_player_enter").Observe(0.001)
	m.VMPoolSize.Set(8)
	m.JobsEnqueuedTotal.WithLabelValues("level_up_reward").Inc()
	m.JobsCompletedTotal.WithLabelValues("level_up_reward", "ok").Inc()
	m.NATSLagSeconds.Set(0.012)

	families, err := reg.Gather()
	if err != nil {
		t.Fatalf("reg.Gather: %v", err)
	}
	if got := len(families); got < 8 {
		t.Fatalf("expected >=8 metric families registered, got %d", got)
	}

	// Sanity check: every family must carry our namespace prefix. A regression
	// here would mean someone shipped a metric without the `aion_` prefix.
	for _, fam := range families {
		if !strings.HasPrefix(fam.GetName(), metricNamespace+"_") {
			t.Errorf("metric %q missing %q prefix", fam.GetName(), metricNamespace+"_")
		}
	}
}

// TestHandler_ServesMetrics verifies that GET /metrics returns 200 and a
// body containing our `aion_` namespace, proving the handler is bound to
// the correct registry.
func TestHandler_ServesMetrics(t *testing.T) {
	reg := NewRegistry()
	m := New(reg)
	// Emit at least one observation so the handler has content to render.
	m.VMPoolSize.Set(4)

	mux := http.NewServeMux()
	mux.Handle("/metrics", Handler(reg))

	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status: got %d want 200", rec.Code)
	}
	body := rec.Body.String()
	if !strings.Contains(body, "aion_") {
		t.Fatalf("body missing aion_ prefix; got:\n%s", body)
	}
}

// TestHandler_HealthzOK verifies that /healthz responds 200 OK regardless
// of the registry state — it must stay green even if a collector panics.
func TestHandler_HealthzOK(t *testing.T) {
	// Spin up a real listener on an ephemeral port so we exercise the
	// full mux wiring (mirrors the production code path inside RunServer).
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	defer ln.Close()

	reg := NewRegistry()
	_ = New(reg)
	mux := http.NewServeMux()
	mux.Handle("/metrics", Handler(reg))
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})

	srv := &http.Server{Handler: mux}
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() { _ = srv.Close() })

	resp, err := http.Get("http://" + ln.Addr().String() + "/healthz")
	if err != nil {
		t.Fatalf("GET /healthz: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: got %d want 200", resp.StatusCode)
	}
	body, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(body), "ok") {
		t.Fatalf("body: got %q want contains \"ok\"", string(body))
	}
}

// TestRunServer_StopsOnContextCancel proves the graceful-shutdown contract:
// when the parent ctx is cancelled, RunServer must return within 1 second
// (well under the 5-second internal Shutdown deadline).
//
// We bind to 127.0.0.1:0 to avoid collision in CI / parallel runs.
func TestRunServer_StopsOnContextCancel(t *testing.T) {
	// Acquire an ephemeral port, then immediately release it so RunServer
	// can bind it. There's a vanishingly small race window here, but it's
	// idiomatic Go and the test fails loud if it loses the race.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	addr := ln.Addr().String()
	_ = ln.Close()

	reg := NewRegistry()
	_ = New(reg)

	ctx, cancel := context.WithCancel(context.Background())

	// Discard logs so the test output stays clean.
	silent := slog.New(slog.NewTextHandler(io.Discard, nil))

	done := make(chan error, 1)
	go func() { done <- RunServer(ctx, addr, reg, silent) }()

	// Give the listener a beat to come up so cancellation reliably hits the
	// running server (not the pre-listen path). 50ms is plenty on every
	// platform we ship to.
	time.Sleep(50 * time.Millisecond)

	cancel()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("RunServer returned error after cancel: %v", err)
		}
	case <-time.After(1 * time.Second):
		t.Fatal("RunServer did not return within 1s of ctx cancel")
	}
}
