package main

import (
	"context"
	"testing"
	"time"
)

// TestRampSchedule_LinearRate 验证 RampSchedule 把 N concurrency / T duration
// 正确换算成稳态 rate=N/T。
func TestRampSchedule_LinearRate(t *testing.T) {
	rate := RampSchedule(500, 60*time.Second)
	want := 500.0 / 60.0
	if rate != want {
		t.Fatalf("RampSchedule(500, 60s) = %f, want %f", rate, want)
	}
}

// TestRampSchedule_ZeroDurationIsImmediate 验证 ramp=0 时立即全开
// （不 panic、rate 不为 NaN/Inf）。
func TestRampSchedule_ZeroDurationIsImmediate(t *testing.T) {
	r := RampSchedule(100, 0)
	if r != 100 {
		t.Fatalf("ramp=0 should return concurrency=100, got %f", r)
	}
}

// TestRampLimiter_StartupIsApproxLinear 验证 60s ramp 500 并发时，
// 在前 t 秒能"领到 token 的 worker 数"约等于 500 * (t/60)。
//
// 关键不变量：误差 ≤ 30%（burst 容许的小抖动 + 调度噪声）。
// 这是"线性 ramp"的可观测下界。
func TestRampLimiter_StartupIsApproxLinear(t *testing.T) {
	if testing.Short() {
		t.Skip("skip in -short")
	}
	const concurrency = 500
	const ramp = 2 * time.Second // 缩短测试，10x 数学一致

	r := RampSchedule(concurrency, ramp)
	lim := NewRampLimiter(r)

	ctx, cancel := context.WithTimeout(context.Background(), ramp)
	defer cancel()

	// 用一个 buffered channel 收集"我领到 token 了"的事件。
	got := make(chan struct{}, concurrency*2)
	for i := 0; i < concurrency; i++ {
		go func() {
			if err := lim.Wait(ctx); err == nil {
				got <- struct{}{}
			}
		}()
	}

	// 等到 ramp 一半时间，看已经领到 token 的 worker 数。
	time.Sleep(ramp / 2)
	count := len(got)

	expected := concurrency / 2
	tolerance := expected * 30 / 100
	if count < expected-tolerance || count > expected+tolerance {
		t.Fatalf("after half ramp got %d, expected ~%d ±%d", count, expected, tolerance)
	}
}

// TestWaitToken_RespectsCancel 验证 ctx cancel 后 limiter.Wait 立即返回 err。
func TestWaitToken_RespectsCancel(t *testing.T) {
	// 极慢 limiter（1 token / 10s），用 cancel 强制提前结束。
	lim := NewRampLimiter(0.1)
	// 先消耗掉 burst（1 个）。
	_ = lim.Allow()

	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		time.Sleep(20 * time.Millisecond)
		cancel()
	}()
	t0 := time.Now()
	err := WaitToken(ctx, lim)
	elapsed := time.Since(t0)

	if err == nil {
		t.Fatal("expected error from cancelled WaitToken")
	}
	if elapsed > 200*time.Millisecond {
		t.Fatalf("WaitToken did not honor cancel quickly enough: %v", elapsed)
	}
}

// TestNewRampLimiter_SaneFallback 验证 rate ≤ 0 时不会 panic 且仍能用。
func TestNewRampLimiter_SaneFallback(t *testing.T) {
	lim := NewRampLimiter(0)
	if lim == nil {
		t.Fatal("limiter nil for rate=0")
	}
	// 应至少能拿一次（fallback=1/sec, burst=1）。
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := lim.Wait(ctx); err != nil {
		t.Fatalf("unexpected wait err: %v", err)
	}
}
