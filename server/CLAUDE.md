# CLAUDE.md — AionCore 5.8 Workspace

## What Is This

AionCore 5.8: a **Go + Lua** reimplementation of the NCSoft AION 5.8 distributed game server.

- **Go** — thin runtime (network I/O, crypto, DB pool, ECS framework, Lua VM host)
- **Lua** — all business logic (skills, combat, AI, quests, packet handlers), hot-reloadable
- **PostgreSQL** — 1314 PL/pgSQL stored procedures (migrated from NCSoft SQL Server)
- **Redis** — session cache, online status (replaces NCSoft's custom CacheD)
- **NATS JetStream** — inter-service event bus (replaces custom TCP IPC)

**Completely independent** from Beyond 4.8 Java server at `../../BEY_4.8/`.

> This is the server-level CLAUDE.md (Go/Lua specifics).
> The full workspace entry point for agents is `../CLAUDE.md` (`ACE_5.8/CLAUDE.md`).

## Architecture

```
5.8 Client → Protocol Gateway (Go, :2108/:7777)
                    ↓ NATS events
             World Engine (Go + Lua ECS)
                    ↓
        PostgreSQL (1314 SPs) + Redis (cache)
```

Five services, not seventeen:

| Service | Code | Port | Purpose |
|---------|------|------|---------|
| Gateway | `src/cmd/gateway/` | 2108, 7777 | AION protocol codec (BF/RSA/XOR), zero game logic |
| World | `src/cmd/world/` | — | ECS game loop + Lua VM, all game logic |
| Chat | `src/cmd/chat/` | 10241 | Channel chat, independently scalable |
| LogD | `src/cmd/logd/` | — | Async log pipeline → ClickHouse |
| Admin | `src/cmd/admin/` | 8080 | REST API + Web dashboard |

## Build & Run

```bash
cd servers/5.8/go/src

# Build all services (2-3 seconds)
go build ./cmd/...

# Run gateway
./gateway -config ../../config/gateway.toml

# Run world engine
./world -config ../../config/world.toml

# Run tests
go test ./... -v
```

## Business Logic: Lua Scripts

All game logic lives in `scripts/`. Hot-reloadable — edit a file, it takes effect within 1 second. No compilation, no restart.

```
scripts/
├── handlers/    Packet handlers (CM_MOVE, CM_ATTACK, etc.)
├── skills/      One file per skill (skill_1001.lua)
├── combat/      Damage formulas, hit check, PvP modifiers
├── ai/          NPC behaviors (patrol, guard, boss)
├── quests/      Quest state machines
├── events/      Event handlers (level up, zone enter)
└── lib/         Shared Lua utilities
```

To add a new skill: create `scripts/skills/skill_XXXX.lua`. Done. No Go code needed.

## Database

Four PostgreSQL databases, all on `127.0.0.1` (NEVER expose to internet):

| Database | Purpose | SP Count |
|----------|---------|----------|
| `aion_world_live` | Game data (characters, items, guilds) | ~1063 |
| `aion_account_db` | Account authentication | ~52 |
| `aion_account_cache_db` | Session cache, rankings | ~101 |
| `aion_gm` | GM operations | ~183 |

**Golden Rule**: NEVER write SQL INSERT/UPDATE/DELETE in Go or Lua. Call the existing stored procedures.

**Migration progress** (snapshot 2026-05-07 03:00 EST): **262 / 1059 SPs ported** (24.7%) across 26 `feat(database): SP batch N` commits + 1 auction closure + 1 P1 sweep, covering 54 business domains; Q1 milestone (50 SPs) achieved at 524%+. Latest commit `fdcb1aa` (auction closure, 00269-00275). Per-batch ledger and "how to append" protocol live in [`doc/migration/STATUS.md`](./doc/migration/STATUS.md).

## Configuration

All config in `config/` as TOML files. Hot-reloadable (world engine watches for changes).

- `gateway.toml` — ports, crypto, DB connection
- `world.toml` — tick rate, max players, Lua settings
- `rates.toml` — exp/drop/kinah multipliers (change without restart)

## Key Constraints

1. **NEVER rewrite stored procedures in Go/Lua** — the 1314 migrated PL/pgSQL functions ARE the business logic
2. **NEVER expose PostgreSQL to internet** — 127.0.0.1 only (ransomware lesson: 2026-04-11)
3. **NEVER hardcode values** — all config from TOML or database
4. **Blowfish is little-endian** — NCSoft non-standard; do NOT use standard crypto libraries
5. **Account name max 17 chars** — RSA credential block size limit
6. **XOR order: XOR-first, ADD-stored, seed 1234** — AL-Login order will corrupt session keys
7. **5.8 client ignores XOR checksum** — accept data even when checksum fails

## Reference Materials

| Resource | Path |
|----------|------|
| Dev guide (Source of Truth) | `doc/dev-guide.md` |
| **SP migration ledger** | [`doc/migration/STATUS.md`](./doc/migration/STATUS.md) |
| NCSoft architecture research | `../../doc/reference/ncsoft-architecture-research.md` |
| L2Auth reverse engineering | `../../doc/reference/downloads/L2Auth/` |
| PTS 4.6 SetupGuide | `../../doc/reference/downloads/pts-46-setup-guide.pdf` |
| NCSoft DB schema (4 databases) | `doc/migration/*_schema.json` |
| Archived C++20 code (BF/RSA ref) | `../../_archive/aioncore-cpp-20260412.tar.gz` |
| Tools (monono2, version-dll, etc.) | `../tools/` |
