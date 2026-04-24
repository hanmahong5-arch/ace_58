# Lua API Reference — AionCore 5.8 Go Bridge

Canonical reference for every global symbol injected by `internal/luahost/bridge.go`
into the gopher-lua VM pool. Read this before editing any file under `server/scripts/`.

- Registration site: `internal/luahost/bridge.go` (`Bridge.Register`)
- Sandbox setup:     `internal/luahost/vm.go` (`openSafeLibs`)
- Go→Lua invoker:    `internal/luahost/invoker.go` (`VMPool.CallGlobal`)

All bridge functions are nil-safe: when a dependency (ECS, Sender, DB, Jobs) is not
wired yet, the call either returns a zero value / empty table / `false,"disabled"`,
or is silently no-op. This lets unit tests and Phase S-0 stubs run without mocks.

---

## Sandbox policy

`openSafeLibs` in `vm.go` creates each VM with `SkipOpenLibs=true`, then loads only:

| Lib    | Opened | Purpose                                  |
|--------|--------|------------------------------------------|
| base   | yes    | `print`, `tostring`, `pcall`, `pairs` …  |
| table  | yes    | `table.insert`, `table.concat` …         |
| string | yes    | `string.format`, `string.sub` …          |
| math   | yes    | `math.floor`, `math.random` …            |
| io     | **stripped** | no disk/stdin/stdout                 |
| os     | **replaced** | custom table containing `os.time` only |
| package / require | **stripped** | no arbitrary module loading   |
| debug  | **stripped** | no introspection/hooks               |
| loadfile / dofile / loadstring | **stripped** | no runtime code load |

### `os.time()` — injected shim

Returns the current Unix timestamp (seconds, integer). This is the only `os.*`
symbol available; it exists because auction expiry math in `scripts/lib/auction.lua`
needs wall-clock time. All other `os` members are `nil`.

```lua
local now = os.time()
local expires_at = now + duration_sec
```

Rationale: exposing the full Lua `os` library would grant `os.execute` /
`os.remove` — unacceptable in a sandbox that loads untrusted-in-principle
scripts. See `vm.go:234-257`.

---

## Global: `log.*`

Structured logging into the server's `slog.Logger`. Every message is prefixed
with `[Lua] ` so operators can grep them out of mixed Go/Lua output.

### `log.info(msg)`
Emit an INFO-level entry.
- `msg` (string) — human-readable line.
- Returns nothing.

```lua
-- scripts/events/on_auction_expire.lua:25
log.info("on_auction_expire: listing_id=" .. tostring(listing_id))
```

### `log.warn(msg)`
Emit a WARN-level entry. Use for recoverable problems (SP returned empty row,
cache miss, etc.).

### `log.error(msg)`
Emit an ERROR-level entry. Use for logic violations that should page someone.

NOTE: these bindings accept one string only. If you want key/value pairs pass
them inside the string (e.g. `"kind=x,err=" .. tostring(err)`). Tables are
not accepted — `L.CheckString(1)` will raise a Lua error.

---

## Global: `db.*`

### `db.call(proc_name, ...) -> rows_table | nil, err_string`
Invoke a PostgreSQL stored procedure. Positional args are converted via
`luaToGo` (bool / number / string / nil only — nested tables become nil).
Returns an array-like Lua table of row tables on success, or `nil, err`
on SP failure. When the DB bridge is not yet wired the call returns an
empty table (never an error), so Phase S-0 scripts can no-op cleanly.

- `proc_name` (string) — SP name, e.g. `"aion_SettleAuction"`.
- Rest (any) — positional SP arguments.
- Returns: `table` (array of `{col_name = value, ...}`), OR `nil, err_string`.

```lua
-- scripts/events/on_auction_expire.lua:32
local rows, err = db.call("aion_SettleAuction", listing_id)
if err then
    log.warn("on_auction_expire: SP err=" .. tostring(err))
    return
end
```

Value conversion for result columns (`goToLua`): bool, int/int32/int64,
float32/float64, string, []byte are mapped natively. Unknown types fall
back to `fmt.Sprintf("%v", ...)` → Lua string.

---

## Global: `entity.*`

Thin wrappers around `ecs.World`. All arguments/returns use numeric entity IDs
(`ecs.Entity` is an integer type).

### `entity.get_position(eid) -> {x, y, z, heading}`
Returns the PositionComp as a Lua table. If the entity has no position set
yet, returns `{x=0,y=0,z=0,heading=0}` (never nil — always safe to index).

### `entity.set_position(eid, x, y, z [, heading])`
Writes PositionComp. `heading` (0–255) is optional and defaults to 0.
WorldID / MapNum already on the component are preserved.

### `entity.get_stat(eid, key) -> number`
Reads a numeric stat from StatBlock. Returns 0 when the stat is absent.

```lua
-- scripts/combat/damage_calc.lua:27
local atk_lvl = entity.get_stat(attacker_id, "level")
```

### `entity.set_stat(eid, key, value)`
Writes a numeric stat. No return.

### `entity.get_nearby(eid, radius) -> {eid, ...}`
Returns an array of entity IDs within `radius` metres (includes NPCs).
O(n) linear scan — do not call per-tick for every player.

### `entity.get_nearby_players(eid, radius) -> {eid, ...}`  (Phase S-7)
Same as `get_nearby` but filters to entities with `PlayerComp`. Used by
chat local/shout broadcast so NPCs don't receive chat packets.

### `entity.get_all_players() -> {eid, ...}`
Snapshot of every connected-player entity ID.

### `entity.get_all_npcs() -> {eid, ...}`
Snapshot of every spawned NPC entity ID.

### `entity.get_gateway_id(eid) -> gateway_seq_id | nil`
Returns the Gateway session ID when the entity has an active `PlayerComp`,
else `nil`. Used before any `player.send_packet` call.

### `entity.get_npc_template(eid) -> template_id`  (Phase S-8)
Returns the NPC template ID from `NpcComp`, or `0` when the entity is
not an NPC. Dialog scripts dispatch on this.

---

## Global: `combat.*`

### `combat.deal_damage(attacker_id, target_id, amount, damage_type) -> remaining_hp`
Subtracts `amount` from target's `hp` stat, clamped to ≥ 0. `damage_type`
is a reserved string (`"physical" | "magical_fire" | ...`), unused in S-0
but persisted for S-5 resist tables.

```lua
-- scripts/skills/skill_1001.lua:39
local remaining = combat.deal_damage(ctx.entity_id, target_id, damage, "physical")
```

### `combat.heal(caster_id, target_id, amount) -> new_hp`
Adds `amount` to target's `hp`, capped at `max_hp` when set. Returns the
new HP value.

### `combat.apply_buff(target_id, buff_id, duration_ticks [, params_table])`
Attaches a non-damaging buff. `duration_ticks` is relative to the current
game tick (converted internally via `Bridge.SetCurrentTick`). Re-applying
the same `buff_id` refreshes the expiry.

### `combat.apply_dot(target_id, dmg_per_tick, duration_ticks, element)`
Attaches a damage-over-time entry. A unique negative buff ID is
auto-assigned so DoTs never collide with positive buff IDs. `element`
defaults to `"physical"`.

### `combat.get_buffs(target_id) -> {{buff_id, is_dot, dmg_per_tick, element, expires_at_tick}, ...}`
Snapshot of all active buff/DoT entries on the entity.

### `combat.purge_expired(target_id, current_tick) -> count_removed`
Removes every buff whose `ExpiresAtTick <= current_tick`. Returns the
number of entries removed.

### `combat.check_hit(attacker_id, target_id) -> bool`
Base hit chance 80 %, ±2 % per level delta, clamped to `[0.10, 0.95]`.
Uses `math/rand` — not seeded with gameplay determinism in mind; if you
need reproducible rolls, use the pure-Lua `hit_check` in
`scripts/combat/damage_calc.lua` instead.

---

## Global: `player.*`

All `gwSeqID` parameters are the Gateway session ID (uint64). Most functions
are DB-backed: they look up `char_id` from ECS, call a stored procedure, and
update the ECS cache on success.

### `player.send_packet(gwSeqID, opcode, payload_string)`
Publishes an `SM_*` packet to the Gateway session via NATS. `payload_string`
is raw binary — build it with `bytes.new()`.

```lua
-- scripts/skills/skill_1001.lua:45-57
local buf = bytes.new()
buf:write_int32(ctx.entity_id)
buf:write_int32(target_id)
-- ...
if gw then player.send_packet(gw, 0x5E, buf:to_string()) end
```

### `player.send_message(gwSeqID, message_string)`
Pushes a SYSTEM-channel chat line (`SM_CHAT` opcode 0x48, channel byte 0x0B,
UTF-16 LE null-terminated). Opcode/format unverified against real 5.8
capture — adjust after first hands-on session.

### `player.set_name(gwSeqID, char_name)` / `player.get_name(gwSeqID) -> string`  (Phase S-7)
Persists the character name on `PlayerComp.CharName` for whisper routing.
`get_name` returns `""` if the session is not mapped.

### `player.find_by_name(char_name) -> eid`
Returns the entity ID of an online player by display name, or `0` when
no match.

### `player.add_item(gwSeqID, item_id, count)`
Calls SP `aion_AddItemUser(char_id, item_id, count)`. Silent no-op on failure
(logs a warning). SP name **unverified** against deployed `aion_world_live`.

### `player.remove_item(gwSeqID, item_id, count) -> bool`
Calls SP `aion_RemoveItemUser`. Returns `true` on SP success.

### `player.get_inventory(gwSeqID) -> {{col=val,...}, ...}`
Calls SP `aion_GetItemsByUser`. Returns the raw row set (column names as
Lua keys).

### `player.add_exp(gwSeqID, exp_amount) -> new_level`
Calls SP `aion_AddExpUser`. Reads the `lev` column from the result row;
falls back to the current ECS `level` stat on SP failure or missing column.

### Kinah (currency, Phase S-8)

- `player.get_kinah(gwSeqID) -> number` — reads cached `kinah` stat.
- `player.add_kinah(gwSeqID, amount) -> bool` — SP `aion_AddKinahUser`,
  updates cache. Negative `amount` is accepted but prefer `spend_kinah`.
- `player.spend_kinah(gwSeqID, amount) -> bool` — atomic check-and-deduct.
  Returns `false` without any DB round-trip when balance is insufficient.
  Cache is rolled back on SP failure so callers see a consistent view.

```lua
-- scripts/lib/auction.lua:104
if not player.spend_kinah(gw, fee) then
    return -1, "insufficient_kinah"
end
```

### Abyss Points (Phase S-11)

- `player.get_ap(gwSeqID) -> number` — cached `abyss_points` stat.
- `player.add_ap(gwSeqID, amount) -> bool` — SP `aion_AddAbyssPointUser`,
  cache rollback on failure. Negative allowed (deduction).
- `player.spend_ap(gwSeqID, amount) -> bool` — atomic check-and-deduct.

All three SP names (`aion_AddKinahUser`, `aion_AddAbyssPointUser`) are flagged
**unverified** in `bridge.go`; confirm against `aion_world_live` catalog
before shipping.

---

## Global: `world.*`

### `world.spawn_npc(template_id, x, y, z) -> eid`
Allocates a new ECS entity with `NpcComp{TemplateID=...}` + `PositionComp`.
Returns `0` when ECS is not wired.

### `world.despawn(eid)`
Destroys the entity and all its components. No return.

### `world.get_zone(eid) -> zone_id`
Returns `PositionComp.WorldID` (0 when unset).

---

## Global: `config.*`

Placeholders for the TOML hot-reload pipeline.

### `config.rates(category, key) -> number`
Always returns `1.0` until the `rates.toml` loader lands.
Example usage: `config.rates("drop", "normal") -> 2.0`.

### `config.get(section, key) -> value`
Always returns `nil` until the TOML loader lands.

Both are **stubbed** — safe to reference, but do not design gameplay around
meaningful return values yet. Track E / S-1 finish them.

---

## Global: `bytes.*`

Binary buffer construction / parsing for packet payloads.
All integer writers use **little-endian** (matches AION wire format).

### Writer — `bytes.new() -> buf`
Returns a mutable byte buffer. All methods use Lua colon syntax (receiver
table is arg 1, data is arg 2).

| Method                     | Effect                                              |
|----------------------------|-----------------------------------------------------|
| `buf:write_byte(n)`        | append 1 byte                                       |
| `buf:write_int16(n)`       | append 2 bytes LE                                   |
| `buf:write_int32(n)`       | append 4 bytes LE                                   |
| `buf:write_int64(n)`       | append 8 bytes LE                                   |
| `buf:write_float32(n)`     | append IEEE-754 float32 LE                          |
| `buf:write_string(s)`      | append raw bytes of `s`                             |
| `buf:write_string_utf16(s)`| UTF-16 LE, auto-appends 2-byte null terminator      |
| `buf:to_string() -> str`   | snapshot current buffer as a Lua string             |
| `buf:len() -> int`         | current byte length                                 |

```lua
-- scripts/npcs/npc_798004.lua:33-40
local buf = bytes.new()
buf:write_int32(session_id)
buf:write_byte(slot_count)
player.send_packet(gw, 0xC8, buf:to_string())
```

### Reader — `bytes.reader(payload_string) -> r`

| Method              | Returns                                          |
|---------------------|--------------------------------------------------|
| `r:read_byte()`     | int (0 on EOF)                                   |
| `r:read_int16()`    | int16 sign-extended                              |
| `r:read_int32()`    | int32 sign-extended                              |
| `r:read_int64()`    | int64 cast to Lua number (precision loss > 2^53) |
| `r:read_float32()`  | number                                           |
| `r:read_string(n)`  | string of `n` raw bytes (empty on EOF)           |
| `r:remaining()`     | bytes left unread                                |

All read-past-EOF calls return the type's zero value — they do **not** raise.
If you need strict parsing, check `r:remaining()` before each read.

---

## Global: `jobq.*`

Async job dispatch backed by `internal/jobq.Bundle` (asynq under the hood).
When `Bridge.Jobs` is nil (no Redis), every call returns `false, "disabled"`.

### `jobq.enqueue(kind, args_table [, delay_sec]) -> ok, err_msg`
- `kind` (string) — registered job kind, e.g. `"aion58.auction.expire"`.
- `args_table` (table|nil) — serialised to JSON; `nil` becomes `{}`.
- `delay_sec` (number, optional) — when `> 0` the dispatch uses
  `EnqueueKindIn` (asynq `ProcessIn`). Zero or omitted = immediate.
- Returns `true` on success, or `false, err_string` on failure.

```lua
-- scripts/lib/auction.lua:125
local ok, reason = jobq.enqueue(
    "aion58.auction.expire",
    { listing_id = listing_id },
    expires_in_sec)
```

Conversion rules (`luaTableToGo`): dense integer-keyed tables become JSON
arrays; all other tables become objects with string keys. Non-string keys
in an object-shaped table are dropped.

---

## Reserved / unavailable

Calling any of these raises `attempt to index a nil value (global 'X')`:

| Symbol                               | Why stripped                                  |
|--------------------------------------|-----------------------------------------------|
| `os.execute`, `os.getenv`, `os.remove`, `os.rename`, `os.exit`, `os.date`, `os.clock`, `os.difftime`, … | Full `os` library is replaced by a stub containing only `os.time`. |
| `io.open`, `io.read`, `io.write`, `io.popen`, `io.lines`, … | Entire `io` library unopened — no disk, no stdio. |
| `package`, `require`, `package.loadlib`, `package.cpath`, `package.path` | No runtime module loading — every script must be under `server/scripts/` and is auto-loaded by `loadScripts`. |
| `debug.*` (`debug.getinfo`, `debug.sethook`, `debug.getregistry`, …) | Sandbox escape surface. |
| `loadfile`, `dofile`, `loadstring`, `load` | Arbitrary code execution; also defeats hot-reload invariants. |

Phase S-0 design choice: the policy is **conservative by default**. If a
genuine need arises (e.g. deterministic RNG), add a narrow shim in
`openSafeLibs` rather than opening the full library.

---

## Calling Lua from Go

Go code dispatches into Lua through `VMPool.CallGlobal(fnName, args...)`
(`internal/luahost/invoker.go`):

- The global must be a `*lua.LFunction`. Otherwise returns
  `ErrLuaGlobalMissing`.
- Args are converted with `goToLua` (bool / int / int32 / int64 /
  float32 / float64 / string / nil supported; other types become `nil`).
- The call runs with `PCall(Protect=true)` — Lua errors become Go errors,
  never crashes. Return values are discarded.
- The VM is acquired and released around the call; CallGlobal is safe to
  invoke from any goroutine.

### Convention: `on_*_expire` / `on_*_deliver` event handlers

`internal/jobq/workers.go` invokes these well-known Lua globals:

| Kind                          | Lua global                 | Args                           |
|-------------------------------|----------------------------|--------------------------------|
| `LuaFnAuctionExpire`          | `on_auction_expire`        | `listing_id`                   |
| `LuaFnLegionInviteExp`        | `on_legion_invite_expire`  | `legion_id, invitee_char_id`   |
| `LuaFnMailDeliver`            | `on_mail_deliver`          | `mail_id, recipient_char_id, …`|
| `LuaFnDailyReset`             | `on_daily_reset`           | —                              |
| `LuaFnPvpAPBatch`             | `on_pvp_ap_batch`          | —                              |
| `LuaFnWorldBossSpawn`         | `on_world_boss_spawn`      | —                              |

Canonical files live under `server/scripts/events/`. Creating the matching
`.lua` file is the only step to bind a new job kind to Lua — no Go change.

### Contract summary

1. Write a top-level `function on_xxx(...) ... end` in
   `server/scripts/events/on_xxx.lua`.
2. Register a job kind → Lua function mapping in
   `internal/jobq/workers.go`.
3. Enqueue from anywhere (Go or `jobq.enqueue` from Lua).
4. Errors in the Lua body surface as wrapped Go errors and are retried by
   asynq according to the kind's retry policy.

---

## Known gaps

- `db.call_async` is referenced in `server/scripts/skills/skill_example.lua:43`
  but **does not exist** in the bridge. The file is a pedagogical stub; treat
  it as planned (Phase S-5). Until implemented, use `db.call` from a worker
  context or `jobq.enqueue` for fire-and-forget DB writes.
- All SP names prefixed `aion_AddKinahUser`, `aion_AddItemUser`,
  `aion_RemoveItemUser`, `aion_GetItemsByUser`, `aion_AddAbyssPointUser`,
  `aion_AddExpUser` are flagged **unverified** in `bridge.go`. Run
  `SELECT proname FROM pg_proc WHERE proname ILIKE 'aion_%'` against
  `aion_world_live` before first live test.
