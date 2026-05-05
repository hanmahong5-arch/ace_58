// Package database — Round 11 / Task A2 benchmark surface.
//
// 这些 benchmark 用 testDSN() (migrate_test.go) 做 env-gate: 没有
// AION_TEST_PG_* 环境变量时干净 b.Skip，CI 默认 go test 就不会失败。
//
// 跑法 (本机有 PG):
//
//	export AION_TEST_PG_HOST=127.0.0.1
//	export AION_TEST_PG_DB=aion_world_live
//	export AION_TEST_PG_USER=postgres
//	export AION_TEST_PG_PASS=...
//	cd server/src
//	go test -run='^$' -bench=. -benchtime=100x -benchmem ./internal/database
//
// 清理 band: 9099000..9099099 (与 sp_*_test.go 的 90007xx / 90008xx band
// 不重叠，避免单测和 bench 互相污染)。
package database

import (
	"context"
	"sync"
	"testing"
	"time"
)

// benchCleanupBandLo / benchCleanupBandHi 是这个文件专用的 char_id 区间。
// 任何 bench 都必须 b.Cleanup(...) 把 band 内的 user_data 行删干净，否则
// 下一次 bench 跑会撞 PRIMARY KEY 或 unique name。
const (
	benchCleanupBandLo = 9099000
	benchCleanupBandHi = 9099099
)

// benchPool 单例 + sync.Once 让多个 bench 共享同一个 *Pool，避免每个
// bench 都付一次 Migrate + NewPool + Ping 的冷启动税。
//
// 注意: testing 框架对 bench 没有 TestMain 之外的 setup hook，所以这里
// 用包级变量 + Once；bench 完成时不主动 Close (进程退出时由 OS 回收)。
var (
	benchPoolOnce   sync.Once
	benchPool       *Pool
	benchPoolReason string
)

// acquireBenchPool 返回一个共享 *Pool，或一个 reason 字符串说明为什么 skip。
func acquireBenchPool(b *testing.B) (*Pool, string) {
	b.Helper()
	benchPoolOnce.Do(func() {
		dsn, reason := testDSN()
		if reason != "" {
			benchPoolReason = reason
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		if err := Migrate(ctx, dsn); err != nil {
			benchPoolReason = "Migrate: " + err.Error()
			return
		}
		p, err := NewPool(ctx, dsn)
		if err != nil {
			benchPoolReason = "NewPool: " + err.Error()
			return
		}
		benchPool = p
	})
	return benchPool, benchPoolReason
}

// benchSeedCleanup 删 band 内所有 user_data 行；bench 启动 + 退出各跑一次。
func benchSeedCleanup(b *testing.B, ctx context.Context, p *Pool) {
	b.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN $1 AND $2`,
		benchCleanupBandLo, benchCleanupBandHi); err != nil {
		b.Fatalf("benchSeedCleanup: %v", err)
	}
}

// BenchmarkSP_GetCharIdByName 测一次 aion_getcharidbyname 调用的端到端
// 延迟 (parse SQL → pgx Query → SP scan → return)。mail.lua 在每封玩家
// 间邮件投递时都调一次，是 mail throughput 的瓶颈。
//
// 提示: -benchtime 默认 1s 会跑出几千次 round-trip，PG 本地是 ~0.5ms/op，
// CI 用 -benchtime=100x 可以在 < 200ms 内完成。
func BenchmarkSP_GetCharIdByName(b *testing.B) {
	pool, reason := acquireBenchPool(b)
	if reason != "" {
		b.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	benchSeedCleanup(b, ctx, pool)
	b.Cleanup(func() {
		benchSeedCleanup(b, context.Background(), pool)
	})

	// Seed 一行让 SP 总能命中 — 测 hot path 而不是 miss path。
	const seedID = 9099001
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'BenchAlice', 'a2bench_alice')`,
		seedID); err != nil {
		b.Fatalf("seed: %v", err)
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		rows, err := pool.CallSP(ctx, "aion_getcharidbyname", "BenchAlice")
		if err != nil {
			b.Fatalf("CallSP: %v", err)
		}
		// 必须 drain rows 否则连接被独占，下一次 Acquire 直接 timeout。
		for rows.Next() {
			var got int
			_ = rows.Scan(&got)
		}
		rows.Close()
	}
}

// BenchmarkSP_GetBindPoint 测 aion_getbindpoint — instance.leave / 死亡
// 复活路径上的核心 SP。返回 5 列 (world,x,y,z,dir) 用 CallSPRow 单行 scan。
func BenchmarkSP_GetBindPoint(b *testing.B) {
	pool, reason := acquireBenchPool(b)
	if reason != "" {
		b.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	benchSeedCleanup(b, ctx, pool)
	b.Cleanup(func() {
		benchSeedCleanup(b, context.Background(), pool)
	})

	const seedID = 9099002
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, 'BenchBind', 'a2bench_bind')`,
		seedID); err != nil {
		b.Fatalf("seed: %v", err)
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		rows, err := pool.CallSP(ctx, "aion_getbindpoint", seedID)
		if err != nil {
			b.Fatalf("CallSP: %v", err)
		}
		for rows.Next() {
			var (
				world   int
				x, y, z float32
				dir     int16
			)
			_ = rows.Scan(&world, &x, &y, &z, &dir)
		}
		rows.Close()
	}
}

// BenchmarkPool_Acquire 测 pgxpool 自身 Acquire/Release 一来一回的成本
// (没有任何 SQL)，给 SP bench 做 baseline: SP_GetCharIdByName 减掉这个
// 数 ≈ 纯 PG round-trip + planner cache 成本。
func BenchmarkPool_Acquire(b *testing.B) {
	pool, reason := acquireBenchPool(b)
	if reason != "" {
		b.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		conn, err := pool.Inner().Acquire(ctx)
		if err != nil {
			b.Fatalf("Acquire: %v", err)
		}
		conn.Release()
	}
}
