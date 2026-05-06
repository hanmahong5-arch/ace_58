// internal/jobq/workers.go
// Worker implementations for the river JobArgs defined in args.go and asynq
// handler bindings for the scheduled / best-effort kinds. World Engine callers
// assemble a WorkerSet at startup, hand it to Config.RiverWorkers, and hand
// the corresponding asynq.ServeMux to Config.AsynqHandler.
//
// Phase S-17: workers delegate the actual business work to Lua event scripts
// via the LuaInvoker interface. The Go side is thus limited to "decode args,
// log, CallGlobal, propagate error". All settlement / item-grant / mail SP
// calls live in Lua (scripts/events/on_*.lua), respecting the "Go is the
// thin runtime, Lua owns business logic" rule from CLAUDE.md.

package jobq

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/hibiken/asynq"
	"github.com/riverqueue/river"
)

// Asynq task kind constants. Callers use these when building asynq.Task
// instances so typos fail at compile time rather than in production.
const (
	KindDailyReset     = "aion58.cron.daily_reset"
	KindPvpAPBatch     = "aion58.cron.pvp_ap_batch"
	KindWorldBossSpawn = "aion58.cron.world_boss_spawn"
	// KindAuctionExpire is a one-shot delayed task scheduled by auction.register
	// with delay = duration_hours * 3600 seconds. The handler delegates to
	// the Lua global `on_auction_expire(listing_id)` which settles via SP.
	KindAuctionExpire = "aion58.auction.expire"

	// KindInstanceExpire is a one-shot delayed task scheduled by instance.create
	// with delay = validity_hours * 3600 seconds. The handler delegates to the
	// Lua global `on_instance_expire(run_id, created_at_unix)`. The payload
	// carries the creation timestamp so a stale task that fires after a server
	// restart (when run_id counters have reset and been recycled) can be
	// rejected as a mismatch instead of tearing down an unrelated new run.
	// See plan-critic round 2 issue #1 in the S-19 plan.
	KindInstanceExpire = "aion58.instance.expire"

	// KindSeasonPoolSwap is a recurring cron task that rotates the global
	// entropy season_pool (5 themed pools defined in scripts/entropy/season_pool.lua).
	// Production schedule is "0 6 * * 1" (every Monday 06:00 server-local time)
	// — a low-traffic window aligned with the ISO-week boundary the
	// `entropy.season_seed()` derivation already uses. The payload carries an
	// explicit season_seed so the cron tick is deterministic / replayable
	// (debugging + offline migration) rather than reading os.time() at
	// firing-time. STORY-21.
	KindSeasonPoolSwap = "aion58.cron.season_pool_swap"
)

// Lua global function names invoked by workers. Keep these in sync with
// scripts/events/on_*.lua; renaming requires a matching script edit.
const (
	LuaFnAuctionExpire     = "on_auction_expire"
	LuaFnLegionInviteExp   = "on_legion_invite_expire"
	LuaFnMailDeliver       = "on_mail_deliver"
	LuaFnDailyReset        = "on_daily_reset"
	LuaFnPvpAPBatch        = "on_pvp_ap_batch"
	LuaFnWorldBossSpawn    = "on_world_boss_spawn"
	LuaFnInstanceExpire    = "on_instance_expire"
	LuaFnSeasonPoolSwap    = "on_season_pool_swap"
)

// --- River workers -------------------------------------------------------

// MailDeliverWorker handles the river side of the in-game mail system.
// Phase S-17 delegates to Lua via Invoker.CallGlobal(LuaFnMailDeliver, ...);
// the Lua script (scripts/events/on_mail_deliver.lua) is responsible for
// calling aion_InsertMailUser + aion_AddItemUser inside the same logical
// transaction. When Invoker is nil the worker logs and returns nil so
// river marks the job completed (dev environment pass-through).
type MailDeliverWorker struct {
	river.WorkerDefaults[MailDeliverArgs]

	// Logger is the structured logger; defaults to slog.Default when nil.
	Logger *slog.Logger
	// Invoker dispatches into Lua; nil disables Lua delegation.
	Invoker LuaInvoker
}

// Work satisfies river.Worker[MailDeliverArgs].
func (w *MailDeliverWorker) Work(ctx context.Context, job *river.Job[MailDeliverArgs]) error {
	log := w.Logger
	if log == nil {
		log = slog.Default()
	}
	log.Info("jobq: mail deliver",
		"sender", job.Args.SenderCharID,
		"recipient", job.Args.RecipientCharID,
		"item", job.Args.AttachedItemID,
		"count", job.Args.AttachedItemCount,
		"kinah", job.Args.AttachedKinah)

	if w.Invoker == nil {
		return nil
	}
	return w.Invoker.CallGlobal(LuaFnMailDeliver,
		job.Args.SenderCharID,
		job.Args.RecipientCharID,
		job.Args.Subject,
		job.Args.Body,
		job.Args.AttachedItemID,
		job.Args.AttachedItemCount,
		job.Args.AttachedKinah)
}

// LegionInviteExpireWorker clears a stale legion invite via the Lua legion
// state machine. Phase S-17 uses Invoker.CallGlobal(LuaFnLegionInviteExp, ...).
type LegionInviteExpireWorker struct {
	river.WorkerDefaults[LegionInviteExpireArgs]
	Logger  *slog.Logger
	Invoker LuaInvoker
}

func (w *LegionInviteExpireWorker) Work(ctx context.Context, job *river.Job[LegionInviteExpireArgs]) error {
	log := w.Logger
	if log == nil {
		log = slog.Default()
	}
	log.Info("jobq: legion invite expire",
		"legion", job.Args.LegionID,
		"inviter", job.Args.InviterEID,
		"target", job.Args.TargetEID)

	if w.Invoker == nil {
		return nil
	}
	return w.Invoker.CallGlobal(LuaFnLegionInviteExp,
		job.Args.LegionID,
		job.Args.InviterEID,
		job.Args.TargetEID)
}

// DefaultRiverWorkers assembles every river.Worker the World Engine ships
// with. Callers pass the result as Config.RiverWorkers. A nil invoker puts
// every worker in "log-only" mode, useful for tests or for running a
// river client in insert-only mode from a separate process.
func DefaultRiverWorkers(logger *slog.Logger, invoker LuaInvoker) *river.Workers {
	ws := river.NewWorkers()
	river.AddWorker(ws, &MailDeliverWorker{Logger: logger, Invoker: invoker})
	river.AddWorker(ws, &LegionInviteExpireWorker{Logger: logger, Invoker: invoker})
	return ws
}

// --- Asynq handlers ------------------------------------------------------

// decodeListingID pulls the integer listing_id field out of a JSON payload.
// Returns zero when the payload is empty / malformed so the Lua side receives
// an explicit 0 and can decide how to handle it.
func decodeListingID(payload []byte) int64 {
	if len(payload) == 0 {
		return 0
	}
	var obj struct {
		ListingID int64 `json:"listing_id"`
	}
	if err := json.Unmarshal(payload, &obj); err != nil {
		return 0
	}
	return obj.ListingID
}

// decodeInstanceExpire pulls the (run_id, created_at_unix) pair out of a JSON
// payload produced by Lua `instance.create`. Missing fields yield zeros so the
// Lua side can surface an explicit stale-expire reject path.
func decodeInstanceExpire(payload []byte) (runID int64, createdAtUnix int64) {
	if len(payload) == 0 {
		return 0, 0
	}
	var obj struct {
		RunID         int64 `json:"run_id"`
		CreatedAtUnix int64 `json:"created_at_unix"`
	}
	if err := json.Unmarshal(payload, &obj); err != nil {
		return 0, 0
	}
	return obj.RunID, obj.CreatedAtUnix
}

// decodeSeasonSeed pulls the season_seed integer out of a JSON payload
// scheduled with KindSeasonPoolSwap. An empty / malformed payload returns 0
// — the Lua handler explicitly validates the value, so feeding it 0 produces
// a deterministic "first pool" rather than a panic. STORY-21.
func decodeSeasonSeed(payload []byte) int64 {
	if len(payload) == 0 {
		return 0
	}
	var obj struct {
		SeasonSeed int64 `json:"season_seed"`
	}
	if err := json.Unmarshal(payload, &obj); err != nil {
		return 0
	}
	return obj.SeasonSeed
}

// DefaultAsynqMux builds the asynq ServeMux with the default World Engine
// handlers. A nil logger is replaced with slog.Default(); a nil invoker
// causes handlers to log-and-return-nil without dispatching into Lua so
// dev environments lacking a loaded VMPool still process queue traffic.
func DefaultAsynqMux(logger *slog.Logger, invoker LuaInvoker) *asynq.ServeMux {
	if logger == nil {
		logger = slog.Default()
	}
	mux := asynq.NewServeMux()

	mux.HandleFunc(KindDailyReset, func(ctx context.Context, t *asynq.Task) error {
		logger.Info("jobq: daily reset tick", "payload_len", len(t.Payload()))
		if invoker == nil {
			return nil
		}
		return invoker.CallGlobal(LuaFnDailyReset)
	})

	mux.HandleFunc(KindPvpAPBatch, func(ctx context.Context, t *asynq.Task) error {
		logger.Info("jobq: pvp ap batch", "payload_len", len(t.Payload()))
		if invoker == nil {
			return nil
		}
		return invoker.CallGlobal(LuaFnPvpAPBatch)
	})

	mux.HandleFunc(KindWorldBossSpawn, func(ctx context.Context, t *asynq.Task) error {
		logger.Info("jobq: world boss spawn", "payload_len", len(t.Payload()))
		if invoker == nil {
			return nil
		}
		return invoker.CallGlobal(LuaFnWorldBossSpawn)
	})

	mux.HandleFunc(KindAuctionExpire, func(ctx context.Context, t *asynq.Task) error {
		listingID := decodeListingID(t.Payload())
		logger.Info("jobq: auction expire tick",
			"listing_id", listingID, "payload_len", len(t.Payload()))
		if invoker == nil {
			return nil
		}
		return invoker.CallGlobal(LuaFnAuctionExpire, listingID)
	})

	mux.HandleFunc(KindInstanceExpire, func(ctx context.Context, t *asynq.Task) error {
		runID, createdAt := decodeInstanceExpire(t.Payload())
		logger.Info("jobq: instance expire tick",
			"run_id", runID, "created_at_unix", createdAt,
			"payload_len", len(t.Payload()))
		if invoker == nil {
			return nil
		}
		return invoker.CallGlobal(LuaFnInstanceExpire, runID, createdAt)
	})

	mux.HandleFunc(KindSeasonPoolSwap, func(ctx context.Context, t *asynq.Task) error {
		seed := decodeSeasonSeed(t.Payload())
		logger.Info("jobq: season pool swap tick",
			"season_seed", seed, "payload_len", len(t.Payload()))
		if invoker == nil {
			return nil
		}
		return invoker.CallGlobal(LuaFnSeasonPoolSwap, seed)
	})

	return mux
}
