// Package main — metrics.go: loadgen 自有 Prometheus registry + per-phase 指标。
//
// 设计选择：
//
//   - **独立 registry**，不复用 telemetry.NewRegistry()/world :9090——避免跟
//     world 真服 metrics 抢端口或污染指标命名空间。loadgen :9091 是默认。
//   - **bucket 按真实 RTT 调**：tinyclient HEAD README 标定 auth ~110ms，
//     enter world ~2s；buckets 必须覆盖到 10s 以内的全部正常 + 长尾区间，
//     否则 p99 会被 +Inf 吞掉。
//   - **per-phase histogram + per-phase error counter** 而非两路 status="ok|err"
//     合并 ——分开看更直观，error rate 也能直接用 increase()/sum()。
//   - **active sessions gauge** 反映 ramp 进度 + 稳态并发量。
package main

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// latencyBuckets 来自 tinyclient HEAD 实测：auth phase 单包 RTT ~10-50ms，
// 整体 auth 110ms，enter world 1-2s。覆盖 1ms..10s 的对数刻度。
var latencyBuckets = []float64{
	0.001, 0.005, 0.01, 0.025, 0.05,
	0.1, 0.25, 0.5, 1, 2.5, 5, 10,
}

// LoadgenMetrics 把 prom 指标对象 + registry 打包；main 只持一份。
type LoadgenMetrics struct {
	Registry *prometheus.Registry

	PhaseLatency    *prometheus.HistogramVec // labels: phase
	PhaseErrors     *prometheus.CounterVec   // labels: phase
	ActiveSessions  prometheus.Gauge
	SessionsStarted prometheus.Counter
	SessionsSuccess prometheus.Counter
	SessionsFailed  prometheus.Counter
}

// NewMetrics 构造一份全新 registry + 指标，并预热所有 phase label
// （否则首次 scrape 时缺线）。
func NewMetrics() *LoadgenMetrics {
	reg := prometheus.NewRegistry()

	m := &LoadgenMetrics{
		Registry: reg,
		PhaseLatency: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Namespace: "loadgen",
			Subsystem: "phase",
			Name:      "latency_seconds",
			Help:      "AION 5.8 协议握手各 phase 的耗时分布（秒）。",
			Buckets:   latencyBuckets,
		}, []string{"phase"}),
		PhaseErrors: prometheus.NewCounterVec(prometheus.CounterOpts{
			Namespace: "loadgen",
			Subsystem: "phase",
			Name:      "errors_total",
			Help:      "各 phase 失败次数累计。",
		}, []string{"phase"}),
		ActiveSessions: prometheus.NewGauge(prometheus.GaugeOpts{
			Namespace: "loadgen",
			Name:      "active_sessions",
			Help:      "当前正在执行 Scenario.Run 的 worker 数。",
		}),
		SessionsStarted: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: "loadgen",
			Name:      "sessions_started_total",
			Help:      "loadgen 启动以来累计创建的 session 数（含失败）。",
		}),
		SessionsSuccess: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: "loadgen",
			Name:      "sessions_success_total",
			Help:      "完整跑完 auth+game+logout 的 session 数。",
		}),
		SessionsFailed: prometheus.NewCounter(prometheus.CounterOpts{
			Namespace: "loadgen",
			Name:      "sessions_failed_total",
			Help:      "Scenario.Run 返回 error 的 session 数。",
		}),
	}

	// 注册到 registry。MustRegister 在重复注册时 panic——这里是新 registry，
	// 不会发生。
	reg.MustRegister(
		m.PhaseLatency, m.PhaseErrors,
		m.ActiveSessions, m.SessionsStarted, m.SessionsSuccess, m.SessionsFailed,
	)

	// 预热每个 phase 的 label，避免首次 scrape 缺线。
	for _, p := range AllPhases {
		m.PhaseLatency.WithLabelValues(string(p))
		m.PhaseErrors.WithLabelValues(string(p))
	}

	return m
}

// ObservePhase 实现 PhaseObserver 接口，被 Scenario 在每个 phase 末尾调用。
func (m *LoadgenMetrics) ObservePhase(p Phase, dur time.Duration, err error) {
	m.PhaseLatency.WithLabelValues(string(p)).Observe(dur.Seconds())
	if err != nil {
		m.PhaseErrors.WithLabelValues(string(p)).Inc()
	}
}
