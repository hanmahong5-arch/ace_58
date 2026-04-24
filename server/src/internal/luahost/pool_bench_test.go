package luahost

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

// benchMockSender is a no-op PacketSender (parallels the test mock but named to
// avoid colliding with symbols in _test.go files of the same package).
type benchMockSender struct{}

func (benchMockSender) SendToPlayer(_ uint64, _ uint16, _ []byte) error { return nil }

// benchMockDB is a no-op DBBridge returning empty result sets.
type benchMockDB struct{}

func (benchMockDB) CallSP(_ context.Context, _ string, _ []any) ([]map[string]any, error) {
	return nil, nil
}

// newMinimalPool creates a VMPool backed by a throw-away scripts directory
// containing one small .lua file that defines the globals the benchmarks call.
// Using a minimal script keeps warm-up time low and focuses the measurement
// on Acquire/Release/CallGlobal cost rather than script-load cost.
func newMinimalPool(b *testing.B, capacity int) (*VMPool, func()) {
	b.Helper()
	dir, err := os.MkdirTemp("", "luahost-bench-*")
	if err != nil {
		b.Fatalf("mkdtemp: %v", err)
	}
	script := `
function noop() end
function add_args(a, b, c) return a + b + c end
`
	if err := os.WriteFile(filepath.Join(dir, "bench.lua"), []byte(script), 0644); err != nil {
		b.Fatalf("write bench.lua: %v", err)
	}
	bridge := &Bridge{DB: benchMockDB{}, Sender: benchMockSender{}}
	pool, err := NewVMPool(capacity, dir, bridge)
	if err != nil {
		os.RemoveAll(dir)
		b.Fatalf("NewVMPool: %v", err)
	}
	cleanup := func() {
		pool.Close()
		os.RemoveAll(dir)
	}
	return pool, cleanup
}

// BenchmarkVMAcquireRelease measures the mutex-guarded pool checkout round-trip.
// Every Lua-dispatched packet handler and every jobq worker invocation incurs
// this cost once, so keeping it below ~1μs is critical at 1800-player CCU.
func BenchmarkVMAcquireRelease(b *testing.B) {
	pool, cleanup := newMinimalPool(b, 4)
	defer cleanup()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		L := pool.Acquire()
		pool.Release(L)
	}
}

// BenchmarkCallGlobal measures the full Acquire + PCall + Release cycle for a
// zero-arg Lua function. This is the cost floor for any Go→Lua dispatch.
func BenchmarkCallGlobal(b *testing.B) {
	pool, cleanup := newMinimalPool(b, 4)
	defer cleanup()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := pool.CallGlobal("noop"); err != nil {
			b.Fatalf("CallGlobal: %v", err)
		}
	}
}

// BenchmarkCallGlobalWithArgs adds three numeric arguments to expose the
// goToLua conversion overhead that dominates for small functions.
func BenchmarkCallGlobalWithArgs(b *testing.B) {
	pool, cleanup := newMinimalPool(b, 4)
	defer cleanup()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := pool.CallGlobal("add_args", 1, 2, 3); err != nil {
			b.Fatalf("CallGlobal: %v", err)
		}
	}
}

