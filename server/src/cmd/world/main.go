// Package main implements the AionCore World Engine (Phase S-2).
//
// Architecture:
//   - Go ECS (Entity-Component-System) manages game state.
//   - Lua VM (gopher-lua) executes all business logic (skills, combat, NPC AI).
//   - PostgreSQL stored procedures handle all persistence.
//   - NATS JetStream receives domain events from Gateway and publishes responses.
//
// Rule: NEVER write game logic in Go.
// If you are implementing combat/skill/quest code here, move it to Lua scripts.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"aion58/internal/config"
	"aion58/internal/database"
	"aion58/internal/ecs"
	"aion58/internal/ipc"
	"aion58/internal/jobq"
	"aion58/internal/luahost"

	"github.com/hibiken/asynq"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})))

	configDir := envOrDefault("AIONCORE_CONFIG_DIR", "../../config")

	loader, err := config.NewLoader(configDir)
	if err != nil {
		slog.Error("world: config loader init failed", "err", err)
		os.Exit(1)
	}
	defer loader.Close()

	worldCfg, err := loader.LoadWorld()
	if err != nil {
		slog.Error("world: load world.toml", "err", err)
		os.Exit(1)
	}

	// Load rates.toml and enable hot-reload.
	if _, err := loader.LoadRates(); err != nil {
		slog.Warn("world: load rates.toml", "err", err)
	}
	if err := loader.WatchRates(); err != nil {
		slog.Warn("world: watch rates.toml", "err", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Connect to PostgreSQL (aion_world_live) for SP calls.
	db, err := database.NewPool(ctx, worldCfg.Database.PoolDSN())
	if err != nil {
		slog.Warn("world: database unavailable at startup", "err", err)
		db = nil
	} else {
		defer db.Close()
		slog.Info("world: database connected")

		// Sprint -1 Track B: apply embedded SQL migrations (sql/schema/*).
		// In production a migration failure aborts startup so the runtime
		// never speaks to a half-deployed schema. AIONCORE_SKIP_MIGRATIONS
		// is provided for emergency overrides only — never set it on prod.
		if os.Getenv("AIONCORE_SKIP_MIGRATIONS") == "" {
			if mErr := database.Migrate(ctx, worldCfg.Database.DSN()); mErr != nil {
				slog.Error("world: migrations failed — aborting", "err", mErr)
				os.Exit(1)
			}
		} else {
			slog.Warn("world: AIONCORE_SKIP_MIGRATIONS set — skipping schema migrations")
		}
	}

	dbAdapter := dbBridgeAdapter{db: db}

	// Build the Go→Lua bridge first. Jobs is set later after jobBundle exists;
	// bridge.Jobs is read at Lua call time, not at Register time, so the
	// VM pool can preload scripts while Jobs is still nil.
	bridge := &luahost.Bridge{
		DB: dbAdapter,
	}

	// Initialise the Lua VM pool (one VM per goroutine).
	// Phase S-17: the pool doubles as the LuaInvoker for background jobq
	// workers; see initJobQueue below.
	vmPool, err := luahost.NewVMPool(
		worldCfg.Server.MaxPlayers/100+1,
		worldCfg.Lua.ScriptsDir,
		bridge,
	)
	if err != nil {
		slog.Error("world: Lua VM pool init failed", "err", err)
		os.Exit(1)
	}
	defer vmPool.Close()

	// Phase S-13: durable job queue (river + asynq). Phase S-17: vmPool is
	// wired in as LuaInvoker so background workers dispatch into Lua event
	// scripts (on_auction_expire / on_mail_deliver / on_legion_invite_expire).
	jobBundle := initJobQueue(ctx, db, worldCfg.Redis, vmPool)
	defer jobBundle.Close(context.Background())

	// Late-bind Jobs onto the bridge — from this point on Lua jobq.enqueue
	// calls land on the real asynq client.
	bridge.Jobs = jobBundle

	// Start Lua hot-reload watcher if enabled.
	if worldCfg.Lua.HotReload {
		if err := vmPool.WatchScripts(); err != nil {
			slog.Warn("world: script watcher unavailable", "err", err)
		} else {
			vmPool.StartWatchLoop()
			slog.Info("world: Lua hot-reload active", "dir", worldCfg.Lua.ScriptsDir)
		}
	}

	// Connect to NATS for inter-service events.
	natsClient, natsErr := ipc.NewClient(worldCfg.NATS.URL)
	if natsErr != nil {
		slog.Warn("world: NATS unavailable — running without event bus", "err", natsErr)
		natsClient = ipc.NewNilClient()
	}
	defer natsClient.Close()

	// Create the ECS world and Dispatcher, then wire both the PacketSender and
	// the ECS reference back into the bridge so Lua scripts can call
	// player.send_packet(), entity.*, and world.*.
	ecsWorld := ecs.NewWorld()
	bridge.ECS = ecsWorld // wire ECS before any Lua calls are made
	dispatcher := newDispatcher(natsClient, vmPool, ecsWorld, dbAdapter)
	bridge.Sender = dispatcher // wire after dispatcher is created

	// Subscribe to player lifecycle events.  Dispatcher manages all session state.
	unsubEnter, err := ipc.Subscribe[ipc.PlayerEnterEvent](natsClient, ipc.SubjectPlayerEnter,
		dispatcher.onPlayerEnter)
	if err != nil {
		slog.Warn("world: subscribe player.enter failed", "err", err)
	} else {
		defer unsubEnter()
	}

	unsubLeave, err := ipc.Subscribe[ipc.PlayerLeaveEvent](natsClient, ipc.SubjectPlayerLeave,
		dispatcher.onPlayerLeave)
	if err != nil {
		slog.Warn("world: subscribe player.leave failed", "err", err)
	} else {
		defer unsubLeave()
	}

	// Start the job queue workers once the rest of the wiring is in place.
	if err := jobBundle.Start(ctx); err != nil {
		slog.Warn("world: jobq start failed", "err", err)
	}

	slog.Info("world: ready",
		"tick_rate", worldCfg.Server.TickRate,
		"max_players", worldCfg.Server.MaxPlayers,
		"lua_scripts", worldCfg.Lua.ScriptsDir,
		"hot_reload", worldCfg.Lua.HotReload,
		"nats", natsClient.IsConnected())

	// Start the ECS game loop.  bridge.SetCurrentTick is called before onTick so
	// Lua buff/skill APIs can convert relative durations to absolute expiry ticks.
	startGameLoop(ctx, worldCfg.Server.TickRate, func(tick int64) {
		bridge.SetCurrentTick(tick)
		dispatcher.onTick(tick)
	})
	slog.Info("world: game loop started", "tick_rate", worldCfg.Server.TickRate)

	waitForShutdown()
	slog.Info("world: shutting down")
}

// --- DB bridge adapter ---

// dbBridgeAdapter adapts *database.Pool to the luahost.DBBridge interface.
type dbBridgeAdapter struct {
	db *database.Pool
}

func (a dbBridgeAdapter) CallSP(ctx context.Context, name string, args []any) ([]map[string]any, error) {
	if a.db == nil {
		return nil, nil
	}

	rows, err := a.db.CallSP(ctx, name, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// Convert pgx rows into []map[string]any for Lua consumption.
	descs := rows.FieldDescriptions()
	var result []map[string]any
	for rows.Next() {
		vals, err := rows.Values()
		if err != nil {
			return nil, err
		}
		row := make(map[string]any, len(descs))
		for i, fd := range descs {
			row[string(fd.Name)] = vals[i]
		}
		result = append(result, row)
	}
	return result, rows.Err()
}

// waitForShutdown blocks until SIGTERM or SIGINT is received.
func waitForShutdown() {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// initJobQueue wires the durable job queue facade. Both backends are
// optional: river is enabled only when the PG pool is live, asynq only when
// the Redis address is non-empty. The returned bundle is always non-nil so
// callers can treat every jobq.* access as safe.
//
// Phase S-17: the invoker argument is forwarded to DefaultRiverWorkers and
// DefaultAsynqMux so workers can call Lua event scripts. Pass a non-nil
// *luahost.VMPool in production and nil in tests or dev environments where
// a VM pool is not yet available.
func initJobQueue(ctx context.Context, db *database.Pool, redisCfg config.RedisConfig, invoker jobq.LuaInvoker) *jobq.Bundle {
	pool := db.Inner()

	var redisOpt *asynq.RedisClientOpt
	if redisCfg.Addr != "" {
		redisOpt = &asynq.RedisClientOpt{
			Addr:     redisCfg.Addr,
			DB:       redisCfg.DB,
			PoolSize: redisCfg.PoolSize,
		}
	}

	cfg := jobq.Config{
		PGPool:        pool,
		RedisOpt:      redisOpt,
		Logger:        slog.Default(),
		RiverWorkers:  jobq.DefaultRiverWorkers(slog.Default(), invoker),
		AsynqHandler:  jobq.DefaultAsynqMux(slog.Default(), invoker),
		RunMigrations: pool != nil, // auto-migrate river tables on dev startup
	}

	bundle, err := jobq.New(ctx, cfg)
	if err != nil {
		slog.Warn("world: jobq init failed — running without background jobs", "err", err)
		// Return a zero bundle (nil-safe) so callers still get a valid handle.
		empty, _ := jobq.New(ctx, jobq.Config{Logger: slog.Default()})
		return empty
	}
	slog.Info("world: jobq ready",
		"river", pool != nil,
		"asynq", redisOpt != nil,
		"invoker", invoker != nil)
	return bundle
}

// startGameLoop runs the ECS tick loop in a background goroutine.
// fn is called once per tick with a monotonically increasing counter (1-based).
// The goroutine exits cleanly when ctx is cancelled.
func startGameLoop(ctx context.Context, tickRate int, fn func(tick int64)) {
	if tickRate <= 0 {
		tickRate = 20 // safe default: 20 ticks/sec
	}
	interval := time.Second / time.Duration(tickRate)
	ticker := time.NewTicker(interval)

	go func() {
		defer ticker.Stop()
		var tick int64
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				tick++
				fn(tick)
			}
		}
	}()
}
