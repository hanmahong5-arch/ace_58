# AionCore 5.8 Development Guide
# AionCore 5.8 开发指南

> **Version**: 2.0 | **Date**: 2026-04-12 | **Architecture**: Go + Lua + PG SP
> **Purpose**: Source of Truth for all AI agents and developers working on AionCore 5.8.
> **Supersedes**: `aioncore-dev-constraints-cpp-archived.md` (C++20 version, archived)

---

## 0. Golden Rules / 黄金法则

1. **NEVER rewrite stored procedures in Go or Lua.** The 1314 PL/pgSQL functions ARE the business logic. Call them.
2. **NEVER put game logic in Go.** Go is the runtime. Lua scripts hold all game logic. If you're writing combat/skill/quest code in Go, you're doing it wrong.
3. **NEVER expose PostgreSQL to internet.** 127.0.0.1 only.
4. **NEVER hardcode values.** Config comes from TOML files or database.
5. **Lock before edit.** Run `sg lock 5.8` before modifying AionCore code.

---

## 1. Architecture / 三层架构

```
Layer 1: Go Runtime (THIN — rarely changes)
  ├── Network I/O (TCP server, packet framing)
  ├── Crypto (BF LE, RSA, XOR — ported from C++ reference)
  ├── DB connection pool (pgx)
  ├── Lua VM host (gopher-lua)
  ├── ECS framework (game state)
  ├── Redis client (session cache)
  └── NATS client (event bus)

Layer 2: Lua Scripts (THICK — changes constantly, hot-reload)
  ├── Packet handlers (CM_*/SM_*)
  ├── Skill effects
  ├── Combat formulas
  ├── NPC AI behaviors
  ├── Quest logic
  └── Event handlers

Layer 3: PostgreSQL Stored Procedures (STABLE — changes rarely)
  └── 1314 PL/pgSQL functions (data CRUD, transactions, integrity)
```

**Token efficiency rule**: 90% of changes should be in Layer 2 (Lua) or config files. These require ~500 tokens per change. Layer 1 (Go) changes require ~3000 tokens — minimize these.

---

## 2. Go Coding Conventions / Go 编码规范

### 2.1 Project Layout

```
server/
├── cmd/           Entry points (one main.go per service)
│   ├── gateway/   Protocol Gateway
│   ├── world/     World Engine
│   ├── chat/      Chat Service
│   ├── logd/      Log Pipeline
│   └── admin/     Admin API
├── internal/      Private packages (not importable by external code)
│   ├── aionproto/ AION packet codec
│   ├── crypto/    BF(LE), RSA, XOR
│   ├── database/  pgx pool + SP caller
│   ├── luahost/   Lua VM + Go→Lua API bindings
│   ├── ecs/       Entity-Component-System
│   ├── config/    TOML loader + hot-reload watcher
│   ├── ipc/       NATS client wrapper
│   └── telemetry/ Structured logging + metrics
└── go.mod
```

### 2.2 Style Rules

- **Go 1.23+**, use latest stable
- **No frameworks** for HTTP (use `net/http`), no ORMs (use `pgx` raw queries to call SPs)
- **Error handling**: wrap with `fmt.Errorf("context: %w", err)`, never ignore errors
- **Concurrency**: goroutines + channels, no mutexes unless absolutely necessary
- **Naming**: follow standard Go conventions (`CamelCase` exports, `camelCase` internal)
- **Comments**: English, on exported symbols only. Unexported code should be self-documenting.
- **File size**: target < 300 lines per file. Split if larger.
- **Tests**: every `internal/` package must have `_test.go` files

### 2.3 Database Access Pattern

```go
// CORRECT: call stored procedure via pgx
func GetCharacter(ctx context.Context, pool *pgxpool.Pool, playerID int64) (*Character, error) {
    row := pool.QueryRow(ctx, "SELECT * FROM ap_get_character_full($1)", playerID)
    var c Character
    err := row.Scan(&c.ID, &c.Name, /* ... */)
    return &c, err
}

// WRONG: writing raw SQL in Go
// func GetCharacter(...) { pool.QueryRow("SELECT * FROM user_data WHERE id = $1", ...) }
```

### 2.4 Crypto Implementation

Port from archived C++ code (`_archive-aioncore-cpp-20260412.tar.gz`):

| Algorithm | Source Reference | Go Implementation |
|-----------|-----------------|-------------------|
| Blowfish (LE) | `shared/crypto/blowfish.*` | `internal/crypto/blowfish_le.go` |
| RSA-1024 | `shared/crypto/rsa_key_pair.*` | `internal/crypto/rsa.go` |
| XOR cipher | `shared/crypto/xor_cipher.*` | `internal/crypto/xor.go` |
| Packet checksum | `shared/network/packet_crypt.*` | `internal/aionproto/checksum.go` |

**Critical**: Blowfish MUST use little-endian block operations. Standard Go `crypto/blowfish` is big-endian. Write a custom implementation or byte-swap.

---

## 3. Lua Scripting Conventions / Lua 脚本规范

### 3.1 File Organization

```
scripts/
├── handlers/cm_move.lua       One file per packet handler
├── skills/skill_1001.lua      One file per skill
├── ai/patrol.lua              One file per AI behavior
├── combat/damage_calc.lua     Combat subsystems
├── quests/quest_1001.lua      One file per quest
├── events/on_level_up.lua     One file per event type
└── lib/api.lua                API documentation
```

### 3.2 Script Template

```lua
-- scripts/skills/skill_XXXX.lua
-- [Skill Name]: [brief description]

local skill = {}

skill.id = XXXX
skill.cooldown = 8
skill.cast_time = 1.5
skill.mp_cost = 100

skill.on_cast = function(caster, targets, skill_level)
    -- Business logic here
    -- Use API from scripts/lib/api.lua
end

return skill
```

### 3.3 Rules

- **Pure Lua 5.1** (gopher-lua compatibility). No LuaJIT extensions.
- **No global state**. Each script returns a table. State lives in ECS components.
- **No blocking calls**. Use `db.call_async()` for database operations.
- **Error handling**: functions should return `nil, error_message` on failure.
- **Hot-reload safe**: scripts are reloaded atomically. No persistent closures.
- **Comments**: English. Every script starts with a file-level comment.
- **No require() for game modules**: the Go runtime registers all API tables globally.

### 3.4 Available API

See `scripts/lib/api.lua` for the complete API reference. Key tables:
- `combat.*` — damage, healing, buffs
- `entity.*` — ECS queries and mutations
- `db.*` — stored procedure calls
- `player.*` — player-specific operations
- `world.*` — spawning, zones
- `config.*` — hot-reloadable config access
- `log.*` — structured logging

---

## 4. Data Flow / 数据流

### 4.1 Login Flow

```
Client → Gateway: TCP connect :2108
Gateway → Client: SM_KEY (BF static key)
Client → Gateway: CM_LOGIN (RSA encrypted credentials)
Gateway: decrypt RSA → db.call("ap_verify_account")
Gateway → Redis: store session
Gateway → Client: SM_LOGIN_OK + SM_SERVER_LIST
Client → Gateway: CM_PLAY (select server)
Gateway → NATS: publish "player.enter"
World → NATS: subscribe "player.enter"
World: db.call("ap_get_character_list") → Lua handler
World → Gateway → Client: SM_CHARACTER_LIST
```

### 4.2 Gameplay Loop

```
Client → Gateway: CM_MOVE (encrypted)
Gateway: decrypt → publish NATS "player.move"
World: NATS receive → Lua scripts/handlers/cm_move.lua
Lua: update ECS position → broadcast SM_MOVE to nearby
World → Gateway → Client: SM_MOVE (other players)
```

### 4.3 Static Data (Jay Lee Pattern)

At startup, World Engine preloads all template data into ECS:
- Item templates → ECS components (never query DB at runtime)
- NPC templates → ECS components
- Skill templates → Lua skill registry
- Quest templates → Lua quest registry

Only player-specific data is queried on demand via stored procedures.

---

## 5. Configuration / 配置管理

### 5.1 TOML Config Files

All in `config/`. Hot-reloadable (World Engine watches file changes).

```toml
# config/rates.toml — change these without restarting the server
[exp]
solo = 1.0
group = 1.5

[drop]
normal = 2.0
boss = 3.0
```

Access from Lua:
```lua
local drop_rate = config.rates("drop", "normal")  -- returns 2.0
```

### 5.2 Environment Variables

```bash
AIONCORE_DB_PASS=xxx        # DB password (never in config files)
AIONCORE_CONFIG_DIR=config/  # Config directory path
```

---

## 6. Testing / 测试

### 6.1 Go Tests

```bash
cd server
go test ./internal/crypto/ -v      # Unit test crypto
go test ./internal/aionproto/ -v   # Unit test protocol
go test ./... -v                    # All tests
```

### 6.2 Lua Script Tests

```lua
-- scripts/skills/skill_1001_test.lua
local skill = require("skills.skill_1001")
local mock = require("lib.test_mock")

-- Test damage calculation
local caster = mock.player({ attack = 500, level = 50 })
local target = mock.npc({ defense = 200, hp = 5000 })
skill.on_cast(caster, {target}, 10)

assert(target.hp < 5000, "Target should take damage")
assert(target.hp > 0, "Target should survive")
```

### 6.3 Test Isolation

- All tests in `test-YYYY-MM-DD-HHMMSS/` directories
- Complete logs and test reports
- Summaries recorded in `doc/process.md`

---

## 7. Anti-Patterns / 反模式

| Anti-Pattern | Why Wrong | Do This Instead |
|-------------|-----------|-----------------|
| Writing game logic in Go | Requires recompilation, wastes tokens | Write in Lua (hot-reload) |
| Writing SQL in Go/Lua | Bypasses SP architecture | Call `db.call("ap_proc_name", ...)` |
| Using `database/sql` | No pgx features, pool management | Use `pgx/v5` directly |
| Using global Lua state | Hot-reload breaks, race conditions | Return tables from scripts |
| Hardcoding port numbers | Config changes need recompile | Read from TOML config |
| Using standard Blowfish | NCSoft uses LE byte order | Custom `blowfish_le.go` |
| Using AL-Login XOR order | Corrupts session keys | XOR-first, ADD-stored, seed 1234 |
| Storing backups in client dir | CryEngine double-loads | Store outside client dir |
| Connecting PG to remote host | Ransomware risk | Always 127.0.0.1 |

---

## 8. Migration from C++20 / 从 C++20 迁移

The C++20 implementation (Phases S-0 through S-2) has been archived to `_archive-aioncore-cpp-20260412.tar.gz`. Key reference code for porting:

| C++ Source (in archive) | Go Target | Notes |
|------------------------|-----------|-------|
| `shared/crypto/blowfish.*` | `internal/crypto/blowfish_le.go` | MUST preserve LE byte order |
| `shared/crypto/rsa_key_pair.*` | `internal/crypto/rsa.go` | RSA-1024, 17-char name limit |
| `shared/crypto/xor_cipher.*` | `internal/crypto/xor.go` | XOR-first order |
| `shared/network/aion_packet.*` | `internal/aionproto/packet.go` | Packet framing |
| `auth-gate-d/auth_gate_session.*` | `cmd/gateway/` | Login handshake flow |
| `world-server/world_session.*` | Lua `handlers/` | Packet dispatch |
| `sm_init_real.bin` | Test fixture | Validated SM_KEY packet bytes |

---

*This document is the Source of Truth for AionCore 5.8 development. Read it before making any changes.*
