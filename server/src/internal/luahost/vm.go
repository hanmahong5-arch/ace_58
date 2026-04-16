// Package luahost embeds a gopher-lua VM for hot-reloadable game logic.
//
// Architecture:
//   - One lua.LState per goroutine (gopher-lua is not goroutine-safe).
//   - A VMPool maintains N pre-warmed states, checked out for handler dispatch.
//   - An fsnotify watcher detects .lua file changes and atomically refreshes
//     the pool by draining old states and preloading fresh ones.
//
// Safety rules enforced by the sandbox:
//   - No os.*, io.*, package.*, require() for non-API modules.
//   - All database calls are async (via db.call_async).
//   - Scripts must not retain global state (use ECS components instead).
package luahost

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	lua "github.com/yuin/gopher-lua"
)

// VMPool manages a pool of pre-loaded Lua states.
// Each state has all API tables registered and all scripts loaded.
type VMPool struct {
	mu         sync.Mutex
	pool       []*lua.LState
	capacity   int
	scriptsDir string
	bridge     *Bridge
	watcher    *fsnotify.Watcher
	done       chan struct{}
}

// NewVMPool creates a pool of `capacity` Lua VMs, each preloaded with
// all scripts found under scriptsDir.  The bridge provides the Go→Lua API.
func NewVMPool(capacity int, scriptsDir string, bridge *Bridge) (*VMPool, error) {
	if capacity < 1 {
		capacity = 1
	}

	w, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, fmt.Errorf("luahost: create watcher: %w", err)
	}

	p := &VMPool{
		capacity:   capacity,
		scriptsDir: scriptsDir,
		bridge:     bridge,
		watcher:    w,
		done:       make(chan struct{}),
	}

	// Pre-warm the pool.
	for i := 0; i < capacity; i++ {
		state, err := p.newState()
		if err != nil {
			p.Close()
			return nil, fmt.Errorf("luahost: warm VM %d: %w", i, err)
		}
		p.pool = append(p.pool, state)
	}

	return p, nil
}

// WatchScripts starts a background goroutine that hot-reloads all VMs
// when any .lua file under scriptsDir changes.
func (p *VMPool) WatchScripts() error {
	// Watch all subdirectories.
	return filepath.WalkDir(p.scriptsDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if watchErr := p.watcher.Add(path); watchErr != nil {
				slog.Warn("luahost: cannot watch dir", "path", path, "err", watchErr)
			}
		}
		return nil
	})
}

// Acquire checks out a Lua state from the pool.
// The caller MUST call Release when done.  If the pool is empty a new
// temporary state is created (prevents blocking at the cost of warmup delay).
func (p *VMPool) Acquire() *lua.LState {
	p.mu.Lock()
	defer p.mu.Unlock()

	if len(p.pool) > 0 {
		last := p.pool[len(p.pool)-1]
		p.pool = p.pool[:len(p.pool)-1]
		return last
	}

	// Pool exhausted — create a temporary state (logs a warning).
	slog.Warn("luahost: pool exhausted, creating temporary VM")
	state, err := p.newState()
	if err != nil {
		slog.Error("luahost: failed to create temporary VM", "err", err)
		return lua.NewState(lua.Options{SkipOpenLibs: true})
	}
	return state
}

// Release returns a Lua state to the pool.
// If the pool is already at capacity the state is closed instead.
func (p *VMPool) Release(L *lua.LState) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if len(p.pool) < p.capacity {
		p.pool = append(p.pool, L)
	} else {
		L.Close()
	}
}

// Close drains the pool and stops the watcher goroutine.
func (p *VMPool) Close() {
	close(p.done)
	_ = p.watcher.Close()

	p.mu.Lock()
	defer p.mu.Unlock()
	for _, L := range p.pool {
		L.Close()
	}
	p.pool = nil
}

// StartWatchLoop starts the hot-reload background goroutine.
// Must be called after WatchScripts().
func (p *VMPool) StartWatchLoop() {
	go p.watchLoop()
}

func (p *VMPool) watchLoop() {
	const debounce = 500 * time.Millisecond
	var timer *time.Timer

	for {
		select {
		case <-p.done:
			if timer != nil {
				timer.Stop()
			}
			return

		case event, ok := <-p.watcher.Events:
			if !ok {
				return
			}
			if strings.HasSuffix(event.Name, ".lua") &&
				(event.Has(fsnotify.Write) || event.Has(fsnotify.Create)) {
				if timer != nil {
					timer.Stop()
				}
				slog.Info("luahost: change detected", "file", event.Name)
				timer = time.AfterFunc(debounce, p.reload)
			}

		case err, ok := <-p.watcher.Errors:
			if !ok {
				return
			}
			slog.Warn("luahost: watcher error", "err", err)
		}
	}
}

func (p *VMPool) reload() {
	slog.Info("luahost: reloading all Lua VMs")

	newStates := make([]*lua.LState, 0, p.capacity)
	for i := 0; i < p.capacity; i++ {
		state, err := p.newState()
		if err != nil {
			slog.Error("luahost: hot-reload VM failed", "i", i, "err", err)
			for _, s := range newStates {
				s.Close()
			}
			return // keep old states rather than replacing with broken ones
		}
		newStates = append(newStates, state)
	}

	p.mu.Lock()
	old := p.pool
	p.pool = newStates
	p.mu.Unlock()

	for _, s := range old {
		s.Close()
	}
	slog.Info("luahost: hot-reload complete", "vm_count", len(newStates))
}

// newState creates and returns a fully sandboxed, API-loaded Lua state.
func (p *VMPool) newState() (*lua.LState, error) {
	// Open only safe standard libraries; omit io/os/package.
	L := lua.NewState(lua.Options{
		SkipOpenLibs: true,
	})
	openSafeLibs(L)

	// Register Go→Lua API tables.
	p.bridge.Register(L)

	// Load all Lua scripts from scriptsDir.
	if err := loadScripts(L, p.scriptsDir); err != nil {
		L.Close()
		return nil, err
	}

	return L, nil
}

// openSafeLibs opens only the Lua standard libraries that are safe in a
// sandboxed game-logic context.  io, os, package, and debug are excluded.
//
// A minimal `os` table is then injected so game logic can read wall-clock
// time without us having to expose the full os library (which would also
// grant filesystem access via os.execute / os.remove). Only `os.time` is
// provided — it returns the current Unix timestamp in seconds and is used
// by Phase S-16 auction expiry math.
func openSafeLibs(L *lua.LState) {
	safe := []struct {
		name string
		fn   lua.LGFunction
	}{
		{lua.BaseLibName, lua.OpenBase},
		{lua.TabLibName, lua.OpenTable},
		{lua.StringLibName, lua.OpenString},
		{lua.MathLibName, lua.OpenMath},
	}
	for _, lib := range safe {
		L.Push(L.NewFunction(lib.fn))
		L.Push(lua.LString(lib.name))
		L.Call(1, 0)
	}

	// Inject a sandboxed os table with only time() exposed.
	osTbl := L.NewTable()
	L.SetField(osTbl, "time", L.NewFunction(func(L *lua.LState) int {
		L.Push(lua.LNumber(time.Now().Unix()))
		return 1
	}))
	L.SetGlobal("os", osTbl)
}

// loadScripts walks scriptsDir and executes every .lua file.
// Files in lib/ are loaded first so other scripts can access shared utilities.
func loadScripts(L *lua.LState, scriptsDir string) error {
	// Collect paths, prioritising lib/ directory.
	var libFiles, otherFiles []string

	err := filepath.WalkDir(scriptsDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".lua") {
			return nil
		}
		if strings.Contains(filepath.ToSlash(path), "/lib/") {
			libFiles = append(libFiles, path)
		} else {
			otherFiles = append(otherFiles, path)
		}
		return nil
	})
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("luahost: walk scripts: %w", err)
	}

	for _, path := range append(libFiles, otherFiles...) {
		if err := L.DoFile(path); err != nil {
			return fmt.Errorf("luahost: load %s: %w", path, err)
		}
	}
	return nil
}
