// Package luahost — Sprint -1 Track B: Lua-side smoke for the hello-world SP.
//
// Exercises the full Go ↔ Lua ↔ pgx ↔ aion_get_server_time() loop:
//
//   1. Run goose migrations against the configured PG instance.
//   2. Build a real DBBridge backed by *database.Pool.
//   3. Execute a Lua snippet that calls db.call("aion_get_server_time")
//      and inspects the returned row map.
//
// The tuple AION_TEST_PG_HOST / DB / USER / PASS gates the test — missing
// any required var causes Skip with a helpful message, so the default
// `go test ./...` run on a contributor machine without local PG stays green.
//
// Run:
//
//	cd server/src
//	AION_TEST_PG_HOST=127.0.0.1 AION_TEST_PG_DB=aion_world_live \
//	AION_TEST_PG_USER=postgres  AION_TEST_PG_PASS=postgres \
//	go test -count=1 -v -run TestLuaHelloSP ./internal/luahost
package luahost

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"testing"
	"time"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/database"
)

// luaPgEnv collects the AION_TEST_PG_* tuple. Returned reason is "" when
// every required value is present; otherwise it names the first missing var.
type luaPgEnv struct {
	Host string
	Port int
	DB   string
	User string
	Pass string
}

func readLuaPGEnv() (luaPgEnv, string) {
	e := luaPgEnv{Port: 5432}
	if e.Host = os.Getenv("AION_TEST_PG_HOST"); e.Host == "" {
		return e, "AION_TEST_PG_HOST"
	}
	if e.DB = os.Getenv("AION_TEST_PG_DB"); e.DB == "" {
		return e, "AION_TEST_PG_DB"
	}
	if e.User = os.Getenv("AION_TEST_PG_USER"); e.User == "" {
		return e, "AION_TEST_PG_USER"
	}
	if _, ok := os.LookupEnv("AION_TEST_PG_PASS"); !ok {
		return e, "AION_TEST_PG_PASS"
	}
	e.Pass = os.Getenv("AION_TEST_PG_PASS")
	if s := os.Getenv("AION_TEST_PG_PORT"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			e.Port = n
		}
	}
	return e, ""
}

func (e luaPgEnv) DSN() string {
	return fmt.Sprintf(
		"host=%s port=%d dbname=%s user=%s password=%s sslmode=disable",
		e.Host, e.Port, e.DB, e.User, e.Pass)
}

// poolDBAdapter forwards luahost.DBBridge calls to a real database.Pool.
// It mirrors the cmd/world/main.go dbBridgeAdapter so the Lua bridge sees
// the same row-shape (map[colname]any) it does in production.
type poolDBAdapter struct {
	pool *database.Pool
}

func (a poolDBAdapter) CallSP(ctx context.Context, name string, args []any) ([]map[string]any, error) {
	rows, err := a.pool.CallSP(ctx, name, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	descs := rows.FieldDescriptions()
	var out []map[string]any
	for rows.Next() {
		vals, err := rows.Values()
		if err != nil {
			return nil, err
		}
		row := make(map[string]any, len(descs))
		for i, fd := range descs {
			row[string(fd.Name)] = vals[i]
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// TestLuaHelloSP runs migrations, then drives db.call from inside a Lua state
// against the live SP. Asserts the row is non-empty and the timestamp is in
// the same ballpark as the host clock.
func TestLuaHelloSP(t *testing.T) {
	env, missing := readLuaPGEnv()
	if missing != "" {
		t.Skipf("integration skipped: %s not set — see file header", missing)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := database.Migrate(ctx, env.DSN()); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	pool, err := database.NewPool(ctx, env.DSN())
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	defer pool.Close()

	bridge := &Bridge{DB: poolDBAdapter{pool: pool}}

	L := lua.NewState(lua.Options{SkipOpenLibs: true})
	defer L.Close()
	openSafeLibs(L)
	bridge.Register(L)

	// Lua snippet that calls the SP and stores the first row's
	// `aion_get_server_time` column on a global for inspection.
	const snippet = `
		local rows, err = db.call("aion_get_server_time")
		if err then error("db.call err: " .. err) end
		if not rows or #rows == 0 then error("empty result rows") end
		_sp_row = rows[1]
		_sp_value = rows[1].aion_get_server_time
	`
	if err := L.DoString(snippet); err != nil {
		t.Fatalf("lua DoString: %v", err)
	}

	row := L.GetGlobal("_sp_row")
	if _, ok := row.(*lua.LTable); !ok {
		t.Fatalf("_sp_row is not a table: %T", row)
	}

	val := L.GetGlobal("_sp_value")
	if val == lua.LNil {
		t.Fatalf("_sp_value is nil — column name mismatch?")
	}

	// goToLua falls back to fmt.Sprintf("%v", v) for time.Time, so we receive
	// the timestamp as a Lua string. Parse it back to a time.Time and verify
	// it's within ±10s of host now() — the same loose bound used in the Go
	// CallSPRow test, plus a margin for clock skew on shared dev VMs.
	s, ok := val.(lua.LString)
	if !ok {
		t.Fatalf("_sp_value is not a string: %T", val)
	}
	parsed, err := parseFlexibleTimestamp(string(s))
	if err != nil {
		t.Fatalf("parse server time %q: %v", s, err)
	}
	if delta := time.Since(parsed).Abs(); delta > 10*time.Second {
		t.Fatalf("server time drift too large: %v (server=%s host=%s)",
			delta, parsed.UTC(), time.Now().UTC())
	}
}

// parseFlexibleTimestamp tries the formats Go's fmt.Sprintf("%v", time.Time)
// can emit (RFC3339-ish with location, RFC3339Nano, plus a UTC variant).
// Keeps the test resilient to driver/marshaller variations across pgx
// versions without baking an exact format string into the assertion.
func parseFlexibleTimestamp(s string) (time.Time, error) {
	layouts := []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05.999999999 -0700 MST",
		"2006-01-02 15:04:05.999999999 -0700 -0700",
		"2006-01-02 15:04:05 -0700 MST",
	}
	var lastErr error
	for _, layout := range layouts {
		if t, err := time.Parse(layout, s); err == nil {
			return t, nil
		} else {
			lastErr = err
		}
	}
	return time.Time{}, lastErr
}
