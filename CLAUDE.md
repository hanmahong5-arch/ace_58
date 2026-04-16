# CLAUDE.md — ACE_5.8 Workspace (AionCore 5.8)

## What Is This

**ACE_5.8** is the **self-contained workspace** for AionCore — the Go + Lua reimplementation of the NCSoft AION 5.8 distributed game server. Everything you need is in this directory: server code, game client, and tools.

This workspace is **completely independent** from `BEY_4.8/` (Beyond-Aion Java). Do not cross-reference their code.

## Workspace Layout

```
ACE_5.8/
├── server/            # Source code (Go + Lua — shared by prod and dev)
│   ├── src/           # Go runtime
│   │   ├── cmd/gateway/   protocol codec (BF/RSA/XOR)
│   │   ├── cmd/world/     ECS + Lua VM — all game logic
│   │   ├── cmd/chat/      chat service
│   │   ├── cmd/logd/      log pipeline → ClickHouse
│   │   └── cmd/admin/     REST admin API
│   ├── scripts/       # Lua — ALL business logic (hot-reload, no restart)
│   ├── sql/           # PostgreSQL schema + seeds
│   ├── launcher/      # Tauri client launcher
│   ├── doc/
│   │   ├── dev-guide.md   ← Source of Truth
│   │   └── migration/     # NCSoft SQL→PG migration tools
│   └── CLAUDE.md      # Server-level Go/Lua specifics
│
├── prod/              # ★ PRODUCTION environment (live players)
│   ├── config/        # Production TOML (ports 2108/7777, real rates)
│   ├── bin/           # Production binaries (built from server/src/)
│   └── logs/          # Production logs
│
├── dev/               # DEVELOPMENT environment (testing, feature work)
│   ├── config/        # Dev TOML (ports 2208/7877, 10x rates, debug logging)
│   ├── bin/           # Dev binaries
│   └── logs/          # Dev logs
│
├── client/            # NCSoft 5.8 game client (35GB, read-only)
│   └── start64.bat    # prod → 127.0.0.1:2108 | dev → 127.0.0.1:2208
└── tools/             # Dev tools for this workspace
    ├── version-dll/   ├── monono2/   ├── AionNetGate/   └── detours/
```

## Source of Truth

**`server/doc/dev-guide.md`** — read this first before any coding task. It defines the three-layer architecture, Go conventions, Lua patterns, anti-patterns, and all critical constraints.

## Build & Run

```bash
cd server/src

# Build all 5 services (2-3 seconds)
go build ./cmd/... -o ../../prod/bin/   # or ../../dev/bin/

# Run PRODUCTION (live players — ports 2108/7777)
./prod/bin/gateway -config prod/config/gateway.toml
./prod/bin/world   -config prod/config/world.toml

# Run DEVELOPMENT (testing — ports 2208/7877, 10x rates, debug log)
./dev/bin/gateway  -config dev/config/gateway.toml
./dev/bin/world    -config dev/config/world.toml

# Run tests
go test ./... -v
```

## Prod vs Dev Quick Reference

| | prod/ | dev/ |
|--|-------|------|
| Gateway port | 2108 | **2208** |
| World port   | 7777 | **7877** |
| Max players  | 1800 | **50** |
| EXP rate     | 1.0x | **10x** |
| Drop rate    | 2.0x | **10x** |
| Redis DB     | 0/1  | **2/3** |
| Logging      | info | **debug** |
| Hot-reload   | 1s   | **0.5s** |

**Rule**: Always develop and test in `dev/` first. Promote to `prod/` only after validation.

## Adding Game Logic

- **New skill**: create `server/scripts/skills/skill_XXXX.lua` — takes effect in 1 second, no restart
- **New packet handler**: create `server/scripts/handlers/cm_xxxx.lua`
- **Config change**: edit `server/config/*.toml` — world engine watches for changes
- **New Go service**: only for infrastructure (network, DB pool, ECS) — never for game logic

## Architecture

```
5.8 Client → Gateway (Go, :2108/:7777)
                   ↓ NATS JetStream events
            World Engine (Go ECS + Lua VM)
                   ↓
       PostgreSQL (1314 PL/pgSQL SPs) + Redis (session cache)
```

## Databases (127.0.0.1 ONLY — never expose to internet)

| Database | Purpose | SP Count |
|----------|---------|----------|
| `aion_world_live` | Game data (characters, items, guilds) | ~1063 |
| `aion_account_db` | Account authentication | ~52 |
| `aion_account_cache_db` | Session cache, rankings | ~101 |
| `aion_gm` | GM operations | ~183 |

## Key Constraints — Memorize These

1. **NEVER write SQL in Go or Lua** — call the 1314 migrated PL/pgSQL stored procedures
2. **NEVER expose PostgreSQL to internet** — 127.0.0.1 only (ransomware incident: 2026-04-11)
3. **NEVER hardcode values** — all config from TOML or database
4. **Blowfish is little-endian** — NCSoft non-standard; do NOT use standard crypto libraries
5. **Account name max 17 chars** — RSA credential block size limit
6. **XOR order: XOR-first, ADD-stored, seed 1234** — AL-Login order corrupts session keys
7. **5.8 client ignores XOR checksum** — accept data even when checksum fails
8. **All game logic in Lua** — Go code handles network/ECS/DB only

## PAK Files

```
client/Data/         Standard ZIP format (PK\x03\x04)        → Python zipfile
client/Levels/       Aion encrypted format (AF B4 FC FB)     → tools/monono2/
client/Objects/      Aion encrypted format
client/Plugin/       Aion encrypted format
```

Decryption reference: `tools/monono2/Common/FileFormats/Pak/PakReader.cs:167-172`

## DLL Injection (version.dll)

- Framework: `tools/version-dll/`
- Loaded automatically when `client/bin32/version.dll` is placed in client dir
- Build: Visual Studio + `DETOURS_PATH` pointing to `tools/detours/`

## Reference Archive

C++20 implementation (archived 2026-04-12) is at `../_archive/aioncore-cpp-20260412.tar.gz`.
Use `shared/crypto/` from the archive as reference for BF/RSA/XOR port verification only.
