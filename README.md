# AionCore 5.8

Go + Lua reimplementation of the NCSoft AION 5.8 distributed game server.

## Architecture

```
5.8 Client ──► Protocol Gateway (Go, BF/RSA/XOR codec)
                       │ NATS JetStream
                       ▼
                World Engine (Go ECS + Lua VM)
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
     PostgreSQL     Redis      ClickHouse
    (1314 SPs)    (session)     (logs)
```

**Design principle**: Go is a thin runtime (network, crypto, DB pool, ECS, VM host). All business logic lives in Lua — hot-reloadable, no compilation, no restart.

## Services

| Service | Code | Ports (prod / dev) | Purpose |
|---------|------|--------------------|---------|
| Gateway | `server/src/cmd/gateway/` | 2108,7777 / 2208,7877 | AION protocol codec, zero game logic |
| World | `server/src/cmd/world/` | — | ECS game loop + Lua VM, all game logic |
| Chat | `server/src/cmd/chat/` | 10241 | Channel chat, independently scalable |
| LogD | `server/src/cmd/logd/` | — | Async log pipeline to ClickHouse |
| Admin | `server/src/cmd/admin/` | 8080 | REST API + Web dashboard |

## Project Layout

```
server/
├── src/                     Go source
│   ├── cmd/                 5 service binaries
│   └── internal/
│       ├── aionproto/       AION packet codec & opcodes
│       ├── crypto/          Blowfish-LE, RSA-NoPad, XOR (NCSoft-compatible)
│       ├── ecs/             Entity-Component-System framework
│       ├── luahost/         Lua VM pool, Bridge (Go⇄Lua), hot-reload
│       ├── jobq/            Background task queue (river + asynq)
│       ├── database/        pgx connection pool wrapper
│       ├── session/         Player session management
│       ├── ipc/             NATS inter-service messaging
│       ├── config/          TOML hot-reload
│       └── telemetry/       Metrics & tracing
├── scripts/                 Lua business logic (75 files)
│   ├── handlers/            Packet handlers (cm_move, cm_attack, ...)
│   ├── lib/                 Shared modules (pvp, mail, auction, legion, ...)
│   ├── events/              Event hooks (on_tick, on_kill, on_auction_expire, ...)
│   ├── skills/              Per-skill scripts (skill_1001, ...)
│   ├── combat/              Damage formulas, hit checks
│   ├── ai/                  NPC behaviors
│   ├── quests/              Quest state machines
│   └── npcs/                NPC templates
├── sql/                     PostgreSQL schema & seeds
├── config/                  Base TOML configs
├── doc/                     Documentation
│   ├── dev-guide.md         Source of Truth for development
│   └── migration/           NCSoft SQL Server → PostgreSQL migration tools
└── launcher/                Tauri client launcher

dev/                         Development environment (ports +100, 10x rates)
prod/                        Production environment (live players)
```

## Quick Start

### Prerequisites

- Go 1.25+
- PostgreSQL 16+ with 1314 PL/pgSQL stored procedures deployed
- Redis 7+
- NATS Server 2.10+

### Build

```bash
cd server/src
go build ./cmd/...
```

### Run (Development)

```bash
# Copy binaries to dev environment
cp gateway world chat logd admin ../../dev/bin/

# Start services
./dev/bin/gateway -config dev/config/gateway.toml
./dev/bin/world   -config dev/config/world.toml
```

Dev environment: ports 2208/7877, 10x exp/drop rates, debug logging, 50 player cap.

### Run (Production)

```bash
cp gateway world chat logd admin ../../prod/bin/
./prod/bin/gateway -config prod/config/gateway.toml
./prod/bin/world   -config prod/config/world.toml
```

Production: ports 2108/7777, standard rates, info logging, 1800 player cap.

### Test

```bash
cd server/src
go test ./...          # 224 tests, all green
go test ./... -v       # verbose output
```

## Implemented Phases

| Phase | Feature | Tests |
|-------|---------|-------|
| S-0 ~ S-5 | Core runtime: crypto, ECS, protocol codec, Lua VM pool, hot-reload | 30 |
| S-6 | NPC dialog & shop system | +14 |
| S-7 | Group/party system | +12 |
| S-8 | Skill system | +10 |
| S-9 | Quest engine | +12 |
| S-10 | Legion (guild) system | +14 |
| S-11 | PvP combat & Abyss Points | +12 |
| S-12 | Equipment system (15-slot) | +20 |
| S-13 | Background job queue (river + asynq) | +10 |
| S-14 | Mail system | +24 |
| S-15 | Warehouse (account storage) | +17 |
| S-16 | Auction House | +27 |
| S-17 | LuaInvoker bridge (Go→Lua for background workers) | +12 |
| **Total** | | **224** |

## Key Technical Decisions

- **Blowfish is little-endian** — NCSoft non-standard; custom implementation required
- **XOR order: XOR-first, ADD-stored, seed 1234** — differs from AL-Login
- **Account name max 17 chars** — RSA credential block size constraint
- **All SQL via stored procedures** — 1314 migrated PL/pgSQL functions, never inline SQL
- **PostgreSQL 127.0.0.1 only** — never exposed to internet
- **Job queue**: river (PG-backed, transactional) + asynq (Redis-backed, cron/delay)

## Configuration

All config via TOML, hot-reloadable:

| File | Purpose |
|------|---------|
| `gateway.toml` | Ports, crypto keys, DB/Redis connection |
| `world.toml` | Tick rate, max players, Lua VM settings |
| `rates.toml` | Exp/drop/kinah multipliers (change without restart) |

## Adding Game Logic

```bash
# New skill — takes effect in <1s, no restart
echo 'function on_use(caster, target) ... end' > server/scripts/skills/skill_XXXX.lua

# New packet handler
echo 'function handle(session, pkt) ... end' > server/scripts/handlers/cm_xxxx.lua

# Tweak drop rates — instant hot-reload
vim server/config/rates.toml
```

No Go code needed for business logic changes.

## Three-Track Architecture

AionCore runs three parallel implementation tracks sharing the same Lua scripts and stored procedures:

| Track | Language | Status |
|-------|----------|--------|
| **A** (this repo) | Go + Lua | Active development |
| **D** | C++20 | Archived reference (BF/RSA/XOR verification) |
| **E** | Rust + mlua | Early development |

The Lua script layer (`server/scripts/`) and PL/pgSQL stored procedures are the language-agnostic contract binding all three tracks.

## License

Private project. All rights reserved.
