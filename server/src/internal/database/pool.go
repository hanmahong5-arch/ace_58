// Package database wraps pgx/v5 to provide a connection pool and a typed
// stored-procedure caller.
//
// Design contract (from dev-guide.md):
//   - NEVER write raw SQL INSERT/UPDATE/DELETE in Go or Lua.
//   - ALL data operations go through the 1314 PL/pgSQL stored procedures.
//   - Use CallSP / CallSPRow for procedure calls; use pool.QueryRow only for
//     lightweight SELECT 1 health checks.
package database

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Pool wraps pgxpool.Pool with AION-specific helpers.
type Pool struct {
	inner *pgxpool.Pool
	dsn   string
}

// NewPool creates and validates a connection pool for the given DSN.
// The pool is tested with a Ping; startup fails fast if the database
// is unavailable.
func NewPool(ctx context.Context, dsn string) (*Pool, error) {
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, fmt.Errorf("database: parse DSN: %w", err)
	}

	// Connection lifecycle settings tuned for a game server: long-lived
	// connections with generous idle timeout.
	cfg.MaxConnLifetime = 30 * time.Minute
	cfg.MaxConnIdleTime = 5 * time.Minute
	cfg.HealthCheckPeriod = 60 * time.Second

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("database: create pool: %w", err)
	}

	// Ping to validate connectivity at startup.
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("database: ping failed: %w", err)
	}

	slog.Info("database: pool connected", "dsn_prefix", safeDSNPrefix(dsn))
	return &Pool{inner: pool, dsn: dsn}, nil
}

// Close drains and closes all connections.  Call on server shutdown.
func (p *Pool) Close() {
	p.inner.Close()
}

// Ping verifies at least one connection is alive.
func (p *Pool) Ping(ctx context.Context) error {
	return p.inner.Ping(ctx)
}

// Stats returns current pool statistics for metrics/logging.
func (p *Pool) Stats() *pgxpool.Stat {
	return p.inner.Stat()
}

// Inner exposes the underlying pgxpool.Pool for integrations that need a
// raw handle (notably internal/jobq's river driver which consumes a pool
// directly). Returns nil when the receiver is nil so call sites can use
// optional wiring without panicking.
func (p *Pool) Inner() *pgxpool.Pool {
	if p == nil {
		return nil
	}
	return p.inner
}

// CallSP executes a stored procedure that returns a set of rows.
// Usage:
//
//	rows, err := pool.CallSP(ctx, "ap_get_character_list", accountID)
//	defer rows.Close()
//	for rows.Next() { ... }
//
// The procedure is called as: SELECT * FROM procName($1, $2, ...).
func (p *Pool) CallSP(ctx context.Context, procName string, args ...any) (pgx.Rows, error) {
	sql := buildSPCall(procName, len(args))
	rows, err := p.inner.Query(ctx, sql, args...)
	if err != nil {
		return nil, fmt.Errorf("database: %s: %w", procName, err)
	}
	return rows, nil
}

// CallSPRow executes a stored procedure that returns a single row.
// The caller must Scan the returned Row; errors are deferred to Scan.
//
//	var name string
//	err := pool.CallSPRow(ctx, "ap_verify_account", account, passhash).Scan(&name)
func (p *Pool) CallSPRow(ctx context.Context, procName string, args ...any) pgx.Row {
	sql := buildSPCall(procName, len(args))
	return p.inner.QueryRow(ctx, sql, args...)
}

// CallSPExec executes a stored procedure that returns no rows (void procedures).
// Returns an error if execution fails.
func (p *Pool) CallSPExec(ctx context.Context, procName string, args ...any) error {
	sql := buildSPCall(procName, len(args))
	_, err := p.inner.Exec(ctx, sql, args...)
	if err != nil {
		return fmt.Errorf("database: %s: %w", procName, err)
	}
	return nil
}

// InTx executes fn inside a serializable transaction.
// If fn returns an error the transaction is rolled back; otherwise committed.
// Suitable for multi-SP operations that must be atomic.
func (p *Pool) InTx(ctx context.Context, fn func(tx pgx.Tx) error) error {
	tx, err := p.inner.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.Serializable})
	if err != nil {
		return fmt.Errorf("database: begin tx: %w", err)
	}

	if fnErr := fn(tx); fnErr != nil {
		_ = tx.Rollback(ctx)
		return fnErr
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("database: commit tx: %w", err)
	}
	return nil
}

// buildSPCall constructs a parameterised CALL / SELECT statement for a
// stored procedure with n arguments.
// All AION stored procedures are defined as functions (not procedures), so
// we call them via SELECT * FROM procName($1, ...).
func buildSPCall(name string, n int) string {
	if n == 0 {
		return "SELECT * FROM " + name + "()"
	}
	buf := make([]byte, 0, 32+n*5)
	buf = append(buf, "SELECT * FROM "...)
	buf = append(buf, name...)
	buf = append(buf, '(')
	for i := 1; i <= n; i++ {
		if i > 1 {
			buf = append(buf, ',')
		}
		buf = fmt.Appendf(buf, "$%d", i)
	}
	buf = append(buf, ')')
	return string(buf)
}

// safeDSNPrefix extracts just the host:port/dbname portion for safe logging.
// Never logs credentials.
func safeDSNPrefix(dsn string) string {
	for i, c := range dsn {
		if c == ' ' || c == '?' {
			return dsn[:i]
		}
	}
	if len(dsn) > 40 {
		return dsn[:40] + "..."
	}
	return dsn
}
