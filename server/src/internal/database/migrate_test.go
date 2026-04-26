// Package database — migration & SP smoke tests for Sprint -1 Track B.
//
// These tests are gated on the AION_TEST_PG_* env tuple (same convention as
// internal/luahost/integration_pg_test.go). When the tuple is missing the
// tests Skip with a clear message — keeping the default `go test ./...`
// output noise-free for contributors without a local PG.
//
// Required env vars (mirror the production world.toml shape):
//
//	AION_TEST_PG_HOST=127.0.0.1
//	AION_TEST_PG_PORT=5432            (optional, default 5432)
//	AION_TEST_PG_DB=aion_world_live
//	AION_TEST_PG_USER=postgres
//	AION_TEST_PG_PASS=...
//
// Run:
//
//	cd server/src
//	go test -count=1 -run TestMigrate -v ./internal/database
package database

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"testing"
	"time"
)

// testDSN assembles a pgx DSN from the AION_TEST_PG_* env tuple.
// Returns ("", reason) when any required field is missing.
func testDSN() (string, string) {
	host := os.Getenv("AION_TEST_PG_HOST")
	if host == "" {
		return "", "AION_TEST_PG_HOST not set"
	}
	db := os.Getenv("AION_TEST_PG_DB")
	if db == "" {
		return "", "AION_TEST_PG_DB not set"
	}
	user := os.Getenv("AION_TEST_PG_USER")
	if user == "" {
		return "", "AION_TEST_PG_USER not set"
	}
	pass := os.Getenv("AION_TEST_PG_PASS")
	// Empty password is allowed (e.g. trust auth on localhost) but the
	// variable must be set explicitly so the contract is opt-in.
	if _, ok := os.LookupEnv("AION_TEST_PG_PASS"); !ok {
		return "", "AION_TEST_PG_PASS not set"
	}
	port := 5432
	if s := os.Getenv("AION_TEST_PG_PORT"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			port = n
		}
	}
	dsn := fmt.Sprintf(
		"host=%s port=%d dbname=%s user=%s password=%s sslmode=disable",
		host, port, db, user, pass,
	)
	return dsn, ""
}

// TestMigrateAndCallHelloSP runs the full Sprint -1 Track B smoke:
//  1. Migrate() applies the embedded 00001_initial.sql.
//  2. Pool.CallSP("aion_get_server_time") returns a TIMESTAMPTZ.
//  3. The returned time is within ±10s of the host's now() — proving the
//     SP executes server-side and the value round-trips through pgx.
func TestMigrateAndCallHelloSP(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s — see file header for env vars", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	defer pool.Close()

	var serverTime time.Time
	if err := pool.CallSPRow(ctx, "aion_get_server_time").Scan(&serverTime); err != nil {
		t.Fatalf("CallSPRow(aion_get_server_time): %v", err)
	}

	delta := time.Since(serverTime).Abs()
	if delta > 10*time.Second {
		t.Fatalf("server time drift too large: %v (server=%s, host=%s)",
			delta, serverTime.UTC(), time.Now().UTC())
	}
}

// TestMigrateIdempotent verifies that running Migrate twice is a no-op on
// the second invocation. goose's schema-version tracking is what makes this
// work — if it broke, the second call would re-run CREATE EXTENSION and
// CREATE OR REPLACE FUNCTION (harmless but wasteful) or worse, fail outright.
func TestMigrateIdempotent(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate #1: %v", err)
	}
	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate #2 (idempotency): %v", err)
	}
}
