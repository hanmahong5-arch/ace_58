// Package main — ramp.go: 渐进式 worker 启动调度器。
//
// 为什么要 ramp 而非"瞬时甩 N 个 goroutine"：
//
//   - **避免雷击启动**：1000 worker 同时握手会让 gateway accept queue 与
//     PG ap_verify_account 连接池瞬间被打爆，测出来的不是稳态吞吐而是
//     冷启动毛刺。
//   - **观测窗口**：渐进 ramp 过程中能在 grafana 看到"什么并发数下 p99
//     开始劣化"——这是压测核心目的之一。
//
// 实现策略：
//
//   - 用 golang.org/x/time/rate.Limiter 做令牌桶，rate = N/T sessions/sec。
//   - main 起 N 个 worker goroutine，每个 worker loop：
//       limiter.Wait(ctx) → 跑一次 Scenario.Run → 立刻等下一次 token
//   - rate.Limiter 是 lock-free 单 token bucket，1000 worker 抢同一个 limiter
//     的 contention 在生产 prom hot-path 实测下 < 1us，量级远低于网络 RTT。
package main

import (
	"context"
	"time"

	"golang.org/x/time/rate"
)

// NewRampLimiter 返回一个稳态 rate=ratePerSec 的 token bucket。
//
// burst 给一个适中的值（max(1, ratePerSec/4)）：太小则严格匀速但启动慢，
// 太大则又退化到雷击。/4 的经验值意味着 ramp 期内允许"1/4 秒的小抖动"，
// 平摊到 60s ramp / 1000 worker 大概 4 worker/burst，对端 accept queue 抗得住。
func NewRampLimiter(ratePerSec float64) *rate.Limiter {
	if ratePerSec <= 0 {
		ratePerSec = 1
	}
	burst := int(ratePerSec / 4)
	if burst < 1 {
		burst = 1
	}
	return rate.NewLimiter(rate.Limit(ratePerSec), burst)
}

// RampSchedule 计算 ramp 配置：N concurrency over rampDuration → rate per sec。
//
// 返回值即喂给 NewRampLimiter 的参数。
func RampSchedule(concurrency int, rampDuration time.Duration) float64 {
	if rampDuration <= 0 || concurrency <= 0 {
		return float64(concurrency) // 立刻全开
	}
	return float64(concurrency) / rampDuration.Seconds()
}

// WaitToken 是单 worker 调用的"我要起跑了"等待器；包一层是为了让单测
// 用 context.WithTimeout 容易控制。
func WaitToken(ctx context.Context, lim *rate.Limiter) error {
	return lim.Wait(ctx)
}
