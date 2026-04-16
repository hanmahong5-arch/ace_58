// Package jobq is a thin facade over riverqueue/river and hibiken/asynq that
// gives the World Engine a single unified handle for durable background work.
//
// Why two engines:
//   - river  → transactional, PostgreSQL-backed, enqueue-in-same-tx semantics.
//              Use for jobs that MUST commit atomically with business writes
//              (mail delivery with item grant, trade settlement, quest reward).
//   - asynq  → Redis-backed, cron scheduler, priority queues.
//              Use for scheduled / periodic / best-effort work (daily reset,
//              world boss spawn, legion invite expiry, PvP AP batch).
//
// Both dependencies are OPTIONAL at runtime. If the World Engine starts
// without a PG pool, river is disabled; without Redis, asynq is disabled.
// Every public method is nil-safe so game code can enqueue without checking.
//
// Phase S-13: MVP scope is the facade + Start/Close lifecycle + one sample
// river JobArgs (MailDeliverArgs) and one asynq kind (KindDailyReset). Lua
// scripts enqueue via asynq only — see internal/luahost/bridge.go jobq.*.
package jobq

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/hibiken/asynq"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"
)

// LuaInvoker lets background jobq workers dispatch into Lua business logic
// without dragging the luahost package into this one. Implemented by
// luahost.VMPool; Phase S-17 callers are KindAuctionExpire handler,
// KindLegionInviteExpire worker, and MailDeliverWorker.
//
// Implementations MUST be safe for concurrent goroutine use because river /
// asynq invoke Work functions from their own worker pools. The canonical
// implementation borrows a pooled *lua.LState, runs the call under
// pcall, and releases the VM before returning.
//
// Args support the same subset as luahost.goToLua (bool / int{,32,64} /
// float{32,64} / string / nil). A nil Invoker is acceptable — workers that
// call CallGlobal on nil should treat the error as "Lua bridge not wired"
// and either retry later or no-op.
type LuaInvoker interface {
	CallGlobal(fnName string, args ...any) error
}

// Config bundles the optional external dependencies used to construct a Bundle.
// Pass a nil value for any optional field to run without that backend.
type Config struct {
	// PGPool is the pgxpool the database package already manages. River uses
	// this pool directly via the riverpgxv5 driver. If nil, river is disabled.
	PGPool *pgxpool.Pool

	// RedisOpt is the Redis connection spec used by asynq. If nil, asynq is
	// disabled.
	RedisOpt *asynq.RedisClientOpt

	// Logger is the structured logger the facade uses for status and errors.
	// Defaults to slog.Default() when nil.
	Logger *slog.Logger

	// AsynqQueues maps queue name to weight for the asynq server. If empty,
	// a single "default" queue with weight 1 is used.
	AsynqQueues map[string]int

	// AsynqConcurrency is the number of concurrent workers the asynq server
	// runs. Defaults to 10 when zero.
	AsynqConcurrency int

	// RiverWorkers is the registered set of river worker types. A nil value
	// puts the river client in insert-only mode; supply a non-nil bundle via
	// river.NewWorkers + river.AddWorker when the process should also work
	// river jobs (normal World Engine wiring).
	RiverWorkers *river.Workers

	// AsynqHandler is the mux used by the asynq server. Pre-populate with
	// asynq.HandleFunc(kind, handler) before calling New / Start. Nil puts
	// the asynq server in client-only mode (scheduler still runs).
	AsynqHandler *asynq.ServeMux

	// RunMigrations, when true, runs river's embedded migrator on New to
	// create/upgrade the river_* tables. Set false in tests or when the
	// schema is managed out-of-band.
	RunMigrations bool

	// RiverMaxWorkers caps concurrent river workers on the default queue.
	// Defaults to 16 when zero.
	RiverMaxWorkers int
}

// Bundle is the live wiring that game code holds for the lifetime of the
// process. All accessors below are nil-safe; callers may use them even when
// the underlying backend is disabled.
type Bundle struct {
	logger *slog.Logger

	// river-side: the TTx parameter on river.Client is the driver-native
	// transaction type. For riverpgxv5 that is pgx.Tx (not *pgxpool.Pool).
	riverClient *river.Client[pgx.Tx] // nil when PG is unavailable

	// asynq-side
	asynqClient    *asynq.Client    // nil when Redis is unavailable
	asynqServer    *asynq.Server    // nil when Redis is unavailable
	asynqScheduler *asynq.Scheduler // nil when Redis is unavailable
	asynqMux       *asynq.ServeMux  // handler passed through Config; may be nil

	// riverHasWorkers records whether the caller supplied a worker bundle, so
	// Start knows whether to boot the worker loop or keep the client insert-only.
	riverHasWorkers bool
}

// New constructs the facade. It does not start the worker pools — call Start
// after the caller is ready to receive callbacks.
//
// Returns a non-nil Bundle even when both backends are disabled; in that case
// every Enqueue* call is a no-op that logs at debug level.
func New(ctx context.Context, cfg Config) (*Bundle, error) {
	logger := cfg.Logger
	if logger == nil {
		logger = slog.Default()
	}

	b := &Bundle{
		logger:   logger,
		asynqMux: cfg.AsynqHandler,
	}

	if cfg.PGPool != nil {
		if err := b.initRiver(ctx, cfg); err != nil {
			return nil, fmt.Errorf("jobq: init river: %w", err)
		}
	} else {
		logger.Info("jobq: river disabled — no PG pool")
	}

	if cfg.RedisOpt != nil {
		if err := b.initAsynq(cfg); err != nil {
			return nil, fmt.Errorf("jobq: init asynq: %w", err)
		}
	} else {
		logger.Info("jobq: asynq disabled — no Redis opt")
	}

	return b, nil
}

func (b *Bundle) initRiver(ctx context.Context, cfg Config) error {
	driver := riverpgxv5.New(cfg.PGPool)

	if cfg.RunMigrations {
		migrator, mErr := rivermigrate.New(driver, nil)
		if mErr != nil {
			return fmt.Errorf("rivermigrate.New: %w", mErr)
		}
		if _, mErr := migrator.Migrate(ctx, rivermigrate.DirectionUp, nil); mErr != nil {
			return fmt.Errorf("river migrate up: %w", mErr)
		}
		b.logger.Info("jobq: river migrations applied")
	}

	maxWorkers := cfg.RiverMaxWorkers
	if maxWorkers <= 0 {
		maxWorkers = 16
	}

	riverCfg := &river.Config{
		Queues: map[string]river.QueueConfig{
			river.QueueDefault: {MaxWorkers: maxWorkers},
		},
		Workers: cfg.RiverWorkers, // nil → insert-only client
	}

	client, err := river.NewClient(driver, riverCfg)
	if err != nil {
		return fmt.Errorf("river.NewClient: %w", err)
	}
	b.riverClient = client
	b.riverHasWorkers = cfg.RiverWorkers != nil
	b.logger.Info("jobq: river client ready",
		"insert_only", !b.riverHasWorkers,
		"max_workers", maxWorkers)
	return nil
}

func (b *Bundle) initAsynq(cfg Config) error {
	b.asynqClient = asynq.NewClient(*cfg.RedisOpt)

	queues := cfg.AsynqQueues
	if len(queues) == 0 {
		queues = map[string]int{"default": 1}
	}
	concurrency := cfg.AsynqConcurrency
	if concurrency <= 0 {
		concurrency = 10
	}

	b.asynqServer = asynq.NewServer(*cfg.RedisOpt, asynq.Config{
		Concurrency: concurrency,
		Queues:      queues,
	})
	b.asynqScheduler = asynq.NewScheduler(*cfg.RedisOpt, &asynq.SchedulerOpts{
		Location: time.UTC,
	})
	b.logger.Info("jobq: asynq ready",
		"concurrency", concurrency,
		"queues", queues)
	return nil
}

// Start begins the river worker loop, the asynq server, and the asynq scheduler.
// Safe to call even when the corresponding backend is disabled. Start is
// non-blocking: the worker pools run in their own goroutines and continue
// until Close is called.
func (b *Bundle) Start(ctx context.Context) error {
	if b.riverClient != nil && b.riverHasWorkers {
		if err := b.riverClient.Start(ctx); err != nil {
			return fmt.Errorf("jobq: river start: %w", err)
		}
	}
	if b.asynqServer != nil && b.asynqMux != nil {
		if err := b.asynqServer.Start(b.asynqMux); err != nil {
			return fmt.Errorf("jobq: asynq server start: %w", err)
		}
	}
	if b.asynqScheduler != nil {
		if err := b.asynqScheduler.Start(); err != nil {
			return fmt.Errorf("jobq: asynq scheduler start: %w", err)
		}
	}
	return nil
}

// Close gracefully shuts down all started components. Call from the process
// shutdown path. Blocks until workers have drained or the context expires.
func (b *Bundle) Close(ctx context.Context) {
	if b == nil {
		return
	}
	if b.asynqScheduler != nil {
		b.asynqScheduler.Shutdown()
	}
	if b.asynqServer != nil {
		b.asynqServer.Shutdown()
	}
	if b.asynqClient != nil {
		if err := b.asynqClient.Close(); err != nil {
			b.logger.Warn("jobq: asynq close", "err", err)
		}
	}
	if b.riverClient != nil && b.riverHasWorkers {
		if err := b.riverClient.Stop(ctx); err != nil && !errors.Is(err, context.Canceled) {
			b.logger.Warn("jobq: river stop", "err", err)
		}
	}
}

// --- Accessors ------------------------------------------------------------

// RiverClient returns the underlying river client, or nil if unavailable.
// Callers should check for nil before enqueueing river-backed jobs.
func (b *Bundle) RiverClient() *river.Client[pgx.Tx] {
	if b == nil {
		return nil
	}
	return b.riverClient
}

// AsynqClient returns the underlying asynq client, or nil if unavailable.
func (b *Bundle) AsynqClient() *asynq.Client {
	if b == nil {
		return nil
	}
	return b.asynqClient
}

// AsynqScheduler returns the underlying cron scheduler, or nil.
func (b *Bundle) AsynqScheduler() *asynq.Scheduler {
	if b == nil {
		return nil
	}
	return b.asynqScheduler
}

// --- High-level enqueue helpers -------------------------------------------

// EnqueueAsynq submits a pre-built task to asynq. Safe when Redis is
// unavailable: returns (nil, nil) and logs at debug level without error so
// callers can treat the call as fire-and-forget.
func (b *Bundle) EnqueueAsynq(ctx context.Context, task *asynq.Task, opts ...asynq.Option) (*asynq.TaskInfo, error) {
	if b == nil || b.asynqClient == nil {
		if b != nil && b.logger != nil && task != nil {
			b.logger.Debug("jobq: asynq disabled, dropping task", "kind", task.Type())
		}
		return nil, nil
	}
	return b.asynqClient.EnqueueContext(ctx, task, opts...)
}

// RegisterCron installs a periodic asynq task. Returns the scheduler entry ID
// or an empty string when asynq is disabled (treated as a no-op so callers do
// not need to branch on availability in startup code).
func (b *Bundle) RegisterCron(cronspec string, task *asynq.Task, opts ...asynq.Option) (string, error) {
	if b == nil || b.asynqScheduler == nil {
		return "", nil
	}
	return b.asynqScheduler.Register(cronspec, task, opts...)
}

// EnqueueKind satisfies the luahost.JobQueue interface: it constructs an
// asynq.Task from the given kind string + raw JSON payload and submits it.
// Nil-safe: returns nil (no error) when asynq is disabled so Lua scripts that
// rely on background jobs can run in dev environments without Redis.
func (b *Bundle) EnqueueKind(ctx context.Context, kind string, payload []byte) error {
	if b == nil || b.asynqClient == nil {
		if b != nil && b.logger != nil {
			b.logger.Debug("jobq: EnqueueKind dropped (asynq disabled)", "kind", kind)
		}
		return nil
	}
	task := asynq.NewTask(kind, payload)
	_, err := b.asynqClient.EnqueueContext(ctx, task)
	return err
}

// EnqueueKindIn is EnqueueKind with a fixed delay before the task becomes
// eligible for work. Implemented via asynq.ProcessIn. A delay of zero or
// negative falls through to the immediate path so callers do not need a
// separate branch for "maybe delayed" cases. Phase S-16 auction expiry is
// the canonical consumer: each listing schedules a one-shot expire task
// with delay = duration_hours * 3600 seconds.
func (b *Bundle) EnqueueKindIn(ctx context.Context, kind string, payload []byte, delay time.Duration) error {
	if b == nil || b.asynqClient == nil {
		if b != nil && b.logger != nil {
			b.logger.Debug("jobq: EnqueueKindIn dropped (asynq disabled)",
				"kind", kind, "delay", delay)
		}
		return nil
	}
	if delay <= 0 {
		return b.EnqueueKind(ctx, kind, payload)
	}
	task := asynq.NewTask(kind, payload)
	_, err := b.asynqClient.EnqueueContext(ctx, task, asynq.ProcessIn(delay))
	return err
}
