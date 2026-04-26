// Package database — migration runner backed by pressly/goose.
//
// Migrations live in `server/sql/schema/*.sql`. They are embedded into the
// binary via go:embed so the runner has no runtime FS dependency: a single
// `world` binary deploys both the runtime and its schema.
//
// Design notes:
//   - The runner is decoupled from *Pool to keep the Ping/CallSP API surface
//     small. It opens a transient *sql.DB through pgx's stdlib adapter just
//     for the goose Up call, then closes it.
//   - File ordering is enforced by goose's numeric prefix (00001_, 00002_, …);
//     names beyond the prefix are free-form for human readability.
//   - We pin the dialect to "postgres" — the only target AionCore supports.
package database

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

// Migrations holds the embedded schema directory.
//
// The embed path is resolved relative to this source file (internal/database),
// so it walks three levels up to reach server/sql/schema.
//
//go:embed all:migrations
var Migrations embed.FS

// MigrationsDir is the in-FS directory that contains the embedded *.sql files.
// goose.SetBaseFS receives Migrations and goose.Up is invoked with this dir.
const MigrationsDir = "migrations"

// Migrate runs all pending Up migrations against the configured PG instance.
// On success it logs the resulting schema version. On failure it returns an
// error so callers can decide whether to abort startup (recommended for
// production) or warn-and-continue (dev convenience).
func Migrate(ctx context.Context, dsn string) error {
	// Open a transient *sql.DB via the pgx stdlib bridge. goose drives the
	// migration through database/sql, not pgxpool, so we cannot reuse the
	// runtime pool here. The connection is closed before the function returns.
	db, err := sql.Open("pgx", dsn)
	if err != nil {
		return fmt.Errorf("database: open migration conn: %w", err)
	}
	defer db.Close()

	if err := db.PingContext(ctx); err != nil {
		return fmt.Errorf("database: ping migration conn: %w", err)
	}

	goose.SetBaseFS(Migrations)
	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("database: set dialect: %w", err)
	}

	// Capture pre/post versions so the operator log records what landed.
	beforeVer, _ := goose.GetDBVersionContext(ctx, db)

	if err := goose.UpContext(ctx, db, MigrationsDir); err != nil {
		return fmt.Errorf("database: goose up: %w", err)
	}

	afterVer, err := goose.GetDBVersionContext(ctx, db)
	if err != nil {
		return fmt.Errorf("database: read schema version: %w", err)
	}

	slog.Info("database: migrations applied",
		"from_version", beforeVer,
		"to_version", afterVer,
		"applied", afterVer-beforeVer)
	return nil
}

// ensure stdlib is referenced so `import _` style is not needed.
// pgx/stdlib registers "pgx" with database/sql in its init(); we keep an
// explicit reference here to make the dependency intent obvious to readers.
var _ = stdlib.GetDefaultDriver
