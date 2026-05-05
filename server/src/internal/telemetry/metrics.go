// Package telemetry — metric definitions.
//
// This file declares the AionCore observability vocabulary. Every metric:
//   - is namespaced with prefix `aion_` so multi-tenant Prometheus deployments
//     can route by job label and never collide with other exporters;
//   - follows OpenMetrics / Prometheus naming conventions
//     (`_total` for counters, `_seconds` for histograms, base SI units);
//   - has a tightly-scoped label set — see "Cardinality control" below.
//
// Cardinality control (READ THIS BEFORE ADDING A LABEL):
//
//	Prometheus stores ONE time-series per unique label-value combination,
//	indefinitely. Adding a high-cardinality label (char_id, player_name,
//	IP address, request_id) silently turns the exporter into a memory leak
//	and crashes the scraper.
//
//	Allowed label cardinalities for AionCore (verified bounded):
//	  - zone: ~50 zones in 5.8 (worldid range fixed)
//	  - direction: 2 (cm | sm)
//	  - opcode_hex: ~80 client/server opcodes (see internal/aionproto/opcodes.go)
//	  - sp_name: ~150 PG stored procedures (1314 total, ~150 hot path)
//	  - fn_name: ~50 Lua entrypoint globals (handlers/events/skills)
//	  - kind: ~30 jobq kinds
//	  - status: 2 (ok | err)
//
//	NEVER use as a label: char_id, player_name, account_id, ip_address,
//	  packet_payload, sql_text, error_message — log these instead.
package telemetry

import "github.com/prometheus/client_golang/prometheus"

// metricNamespace is prefixed onto every metric. Keeping it as a constant
// makes a future rename (e.g., aion_ → aioncore_) a one-line change.
const metricNamespace = "aion"

// Metrics bundles every AionCore collector behind a single struct so callers
// can pass it down a service tree without 8+ parameters.
//
// Construction: telemetry.New(reg) — ALL collectors are registered against
// the supplied registry inside New(); a constructor failure panics because
// it indicates a duplicate-name programming bug, not a runtime condition.
type Metrics struct {
	// PlayerCount tracks concurrent players per zone. Use Inc/Dec on
	// player-enter / player-leave events. The "zone" label is bounded by
	// the worldid table (~50 zones in 5.8).
	PlayerCount *prometheus.GaugeVec

	// PacketsTotal counts every wire packet, partitioned by direction
	// (cm = client→server, sm = server→client) and opcode_hex (e.g. "0x4B").
	// Prefer hex strings over decimal so labels match dev-guide.md tables.
	PacketsTotal *prometheus.CounterVec

	// SPLatencySeconds measures PostgreSQL stored-procedure call latency.
	// Buckets are tuned for AionCore's typical SP profile: 1ms (cache hit) →
	// 1s (degraded). p99 above 100ms is an alerting threshold.
	SPLatencySeconds *prometheus.HistogramVec

	// LuaCallLatencySeconds measures gopher-lua VMPool.CallGlobal latency
	// per entrypoint name (e.g. "on_player_enter", "cm_move"). High p99
	// here means a hot Lua handler needs profiling.
	LuaCallLatencySeconds *prometheus.HistogramVec

	// VMPoolSize reports the live count of pre-warmed Lua VMs in the pool.
	// A flatline near zero means the pool is exhausted (every Acquire
	// creates a temporary VM — see luahost/vm.go).
	VMPoolSize prometheus.Gauge

	// JobsEnqueuedTotal / JobsCompletedTotal partition jobq throughput by
	// kind (jobq workers identifier) and, for completion, status (ok|err).
	// Subtracting completed-by-kind from enqueued-by-kind gives in-flight.
	JobsEnqueuedTotal  *prometheus.CounterVec
	JobsCompletedTotal *prometheus.CounterVec

	// NATSLagSeconds reports the JetStream consumer lag (newest published
	// message timestamp − newest delivered timestamp). When this rises
	// above the tick budget, the world engine is falling behind.
	NATSLagSeconds prometheus.Gauge
}

// spLatencyBuckets covers 1ms → 1s on a roughly logarithmic curve. Tuned
// for AionCore's hot SP path (most calls 2-20ms; outliers 100ms-1s). Values
// > 1s should fire alerts, not be quantile-bucketed.
var spLatencyBuckets = []float64{
	0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0,
}

// luaLatencyBuckets covers 100µs → 100ms. Lua handlers run inside the world
// engine tick, so anything ≥10ms is a regression worth investigating.
var luaLatencyBuckets = []float64{
	0.0001, 0.00025, 0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1,
}

// New constructs a Metrics bundle and registers all collectors against reg.
//
// Panics if a collector cannot be registered (duplicate name = compile-time
// programming bug; we'd rather crash on boot than silently double-count).
func New(reg *prometheus.Registry) *Metrics {
	m := &Metrics{
		PlayerCount: prometheus.NewGaugeVec(
			prometheus.GaugeOpts{
				Namespace: metricNamespace,
				Name:      "player_count",
				Help:      "Concurrent players currently in-zone, partitioned by zone id.",
			},
			[]string{"zone"},
		),
		PacketsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: metricNamespace,
				Name:      "packets_total",
				Help:      "Total AION protocol packets observed by the gateway, partitioned by direction (cm|sm) and opcode_hex.",
			},
			[]string{"direction", "opcode_hex"},
		),
		SPLatencySeconds: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Namespace: metricNamespace,
				Name:      "sp_latency_seconds",
				Help:      "PostgreSQL stored-procedure call latency in seconds.",
				Buckets:   spLatencyBuckets,
			},
			[]string{"sp_name"},
		),
		LuaCallLatencySeconds: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Namespace: metricNamespace,
				Name:      "lua_call_latency_seconds",
				Help:      "Lua VMPool.CallGlobal latency in seconds, partitioned by entrypoint name.",
				Buckets:   luaLatencyBuckets,
			},
			[]string{"fn_name"},
		),
		VMPoolSize: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: metricNamespace,
				Name:      "vm_pool_size",
				Help:      "Number of pre-warmed Lua VMs currently parked in the pool.",
			},
		),
		JobsEnqueuedTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: metricNamespace,
				Name:      "jobs_enqueued_total",
				Help:      "Total background jobs enqueued, partitioned by kind.",
			},
			[]string{"kind"},
		),
		JobsCompletedTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Namespace: metricNamespace,
				Name:      "jobs_completed_total",
				Help:      "Total background jobs completed, partitioned by kind and status (ok|err).",
			},
			[]string{"kind", "status"},
		),
		NATSLagSeconds: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: metricNamespace,
				Name:      "nats_lag_seconds",
				Help:      "JetStream consumer lag in seconds (publish_ts - deliver_ts of newest message).",
			},
		),
	}

	// Register every collector. MustRegister panics on duplicate, which is
	// what we want — caller bugs should fail loud at boot, not silently
	// shadow metrics at scrape time.
	reg.MustRegister(
		m.PlayerCount,
		m.PacketsTotal,
		m.SPLatencySeconds,
		m.LuaCallLatencySeconds,
		m.VMPoolSize,
		m.JobsEnqueuedTotal,
		m.JobsCompletedTotal,
		m.NATSLagSeconds,
	)

	return m
}
