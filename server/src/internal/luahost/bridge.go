package luahost

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"math/rand"
	"sync/atomic"
	"time"

	"aion58/internal/ecs"

	lua "github.com/yuin/gopher-lua"
)

// jsonMarshal is an alias for encoding/json.Marshal so test code can shadow
// marshalJSONSafe without pulling encoding/json into the hot loop indirection.
var jsonMarshal = json.Marshal

// Bridge holds the Go-side implementations that are exposed as Lua global
// tables.  Inject the real implementations from the World Engine before
// calling Register().
//
// For Phase S-0, all implementations are stubs that log and return.
// The World Engine will replace them with real implementations in Phase S-1/S-2.
type Bridge struct {
	// DB is the Go function that executes a stored procedure.
	// Signature: db.call(proc_name, ...) -> table or nil, error_string
	DB DBBridge

	// Sender allows Lua scripts to push SM_* packets to a Gateway session.
	// Wired to Dispatcher.SendToPlayer after the Dispatcher is created.
	// Nil until the World Engine completes S-2 setup.
	Sender PacketSender

	// ECS is the Entity-Component-System world used by entity.* and world.* calls.
	// Wired after ecs.World is created in the World Engine (Phase S-3).
	ECS *ecs.World

	// Jobs is the background job queue handle used by Lua jobq.* calls.
	// Wired to an internal/jobq.Bundle at the World Engine level (Phase S-13).
	// Nil when the game server runs without Redis — every Lua enqueue call
	// degrades to a debug log in that case.
	Jobs JobQueue

	// Logger is the structured logger used by log.* Lua calls.
	// If nil, slog.Default() is used.
	Logger *slog.Logger

	// currentTick tracks the current game tick, updated by SetCurrentTick each loop.
	// Used internally by apply_buff/apply_dot to convert durations to absolute ticks.
	currentTick atomic.Int64
	// nextDotID generates unique negative IDs for DoT buff entries.
	nextDotID atomic.Int32
}

// SetCurrentTick stores the current game tick so Lua buff APIs can convert
// relative durations to absolute expiry ticks. Call before dispatching on_tick.
func (b *Bridge) SetCurrentTick(tick int64) {
	b.currentTick.Store(tick)
}

// PacketSender is implemented by the Dispatcher and allows Lua scripts to push
// SM_* packets to a specific Gateway session via NATS.
type PacketSender interface {
	// SendToPlayer publishes a packet to the Gateway session identified by
	// gatewaySeqID, which forwards it to the connected game client.
	SendToPlayer(gatewaySeqID uint64, opcode uint16, payload []byte) error
}

// DBBridge is the interface the World Engine provides for stored-procedure calls.
type DBBridge interface {
	// CallSP calls a stored procedure and returns results as a slice of maps.
	CallSP(ctx context.Context, name string, args []any) ([]map[string]any, error)
}

// JobQueue is the interface the World Engine provides for background jobs.
// Implemented by jobq.Bundle. Kept as a small interface here so the luahost
// package does not need to import the jobq package and its transitive deps,
// which would drag river/asynq into every luahost test.
//
// Phase S-13: only the asynq-backed kind dispatch is exposed to Lua. River
// jobs are enqueued from Go code (transactional handlers) and not from Lua.
// Phase S-16: EnqueueKindIn adds delayed dispatch for auction expiry,
// legion invite expiry, and other "run after X seconds" use cases via the
// asynq.ProcessIn option under the hood.
type JobQueue interface {
	// EnqueueKind pushes a task of the given kind with the given JSON-encoded
	// payload. Implementations should be nil-safe and degrade to a warning
	// when the underlying backend is disabled. Returns nil on success.
	EnqueueKind(ctx context.Context, kind string, payload []byte) error

	// EnqueueKindIn is EnqueueKind with a fixed delay before the job becomes
	// eligible for work. A delay of zero is equivalent to EnqueueKind.
	EnqueueKindIn(ctx context.Context, kind string, payload []byte, delay time.Duration) error
}

// Register injects all API tables into the given Lua state.
// Must be called on every new state before loading game scripts.
func (b *Bridge) Register(L *lua.LState) {
	b.registerLog(L)
	b.registerCombat(L)
	b.registerEntity(L)
	b.registerDB(L)
	b.registerPlayer(L)
	b.registerWorld(L)
	b.registerConfig(L)
	b.registerBytes(L)
	b.registerJobq(L)
}

// --- log.* ---

func (b *Bridge) registerLog(L *lua.LState) {
	log := L.NewTable()
	logger := b.logger()

	L.SetField(log, "info", L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logger.Info("[Lua] " + msg)
		return 0
	}))
	L.SetField(log, "warn", L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logger.Warn("[Lua] " + msg)
		return 0
	}))
	L.SetField(log, "error", L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logger.Error("[Lua] " + msg)
		return 0
	}))

	L.SetGlobal("log", log)
}

// --- combat.* ---

func (b *Bridge) registerCombat(L *lua.LState) {
	combat := L.NewTable()

	// combat.deal_damage(attacker_id, target_id, amount, damage_type)
	// Applies `amount` points of damage to the target's "hp" ECS stat.
	// Returns the remaining HP after the hit.
	L.SetField(combat, "deal_damage", L.NewFunction(func(L *lua.LState) int {
		_ = ecs.Entity(L.CheckNumber(1)) // attacker_id (reserved for future modifiers)
		targetID := ecs.Entity(L.CheckNumber(2))
		amount := float64(L.CheckNumber(3))
		_ = L.OptString(4, "physical") // damage_type string, reserved for Phase S-5
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		hp, _ := b.ECS.GetStat(targetID, "hp")
		hp -= amount
		if hp < 0 {
			hp = 0
		}
		b.ECS.SetStat(targetID, "hp", hp)
		L.Push(lua.LNumber(hp))
		return 1
	}))

	// combat.apply_buff(target_id, buff_id, duration_ticks [, params_table])
	// Applies a non-damaging buff.  duration_ticks is relative to current tick.
	// Re-applying the same buff_id refreshes the duration.
	L.SetField(combat, "apply_buff", L.NewFunction(func(L *lua.LState) int {
		targetID := ecs.Entity(L.CheckNumber(1))
		buffID := int32(L.CheckNumber(2))
		durationTicks := int64(L.CheckNumber(3))
		if b.ECS == nil {
			return 0
		}
		expiresAt := b.currentTick.Load() + durationTicks
		b.ECS.AddBuff(targetID, &ecs.BuffEntry{
			BuffID:        buffID,
			ExpiresAtTick: expiresAt,
		})
		return 0
	}))

	// combat.apply_dot(target_id, dmg_per_tick, duration_ticks, element)
	// Applies a damage-over-time effect.  Each tick of on_tick deals dmg_per_tick.
	// duration_ticks is relative; a unique negative ID is auto-assigned.
	L.SetField(combat, "apply_dot", L.NewFunction(func(L *lua.LState) int {
		targetID := ecs.Entity(L.CheckNumber(1))
		dmgPerTick := float64(L.CheckNumber(2))
		durationTicks := int64(L.CheckNumber(3))
		element := L.OptString(4, "physical")
		if b.ECS == nil {
			return 0
		}
		id := b.nextDotID.Add(-1) // unique negative ID; won't collide with positive buff IDs
		expiresAt := b.currentTick.Load() + durationTicks
		b.ECS.AddBuff(targetID, &ecs.BuffEntry{
			BuffID:        id,
			IsDot:         true,
			DamagePerTick: dmgPerTick,
			Element:       element,
			ExpiresAtTick: expiresAt,
		})
		return 0
	}))

	// combat.get_buffs(target_id) -> [{buff_id, is_dot, dmg_per_tick, element, expires_at_tick}, ...]
	// Returns a snapshot of all active buffs and DoTs on the entity.
	L.SetField(combat, "get_buffs", L.NewFunction(func(L *lua.LState) int {
		targetID := ecs.Entity(L.CheckNumber(1))
		result := L.NewTable()
		if b.ECS != nil {
			for i, entry := range b.ECS.GetBuffs(targetID) {
				t := L.NewTable()
				L.SetField(t, "buff_id", lua.LNumber(entry.BuffID))
				L.SetField(t, "is_dot", lua.LBool(entry.IsDot))
				L.SetField(t, "dmg_per_tick", lua.LNumber(entry.DamagePerTick))
				L.SetField(t, "element", lua.LString(entry.Element))
				L.SetField(t, "expires_at_tick", lua.LNumber(float64(entry.ExpiresAtTick)))
				result.RawSetInt(i+1, t)
			}
		}
		L.Push(result)
		return 1
	}))

	// combat.purge_expired(target_id, current_tick) -> count_removed
	// Removes all BuffEntries whose ExpiresAtTick <= current_tick.
	// Returns the number of entries removed.
	L.SetField(combat, "purge_expired", L.NewFunction(func(L *lua.LState) int {
		targetID := ecs.Entity(L.CheckNumber(1))
		tick := int64(L.CheckNumber(2))
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		removed := b.ECS.RemoveExpiredBuffs(targetID, tick)
		L.Push(lua.LNumber(len(removed)))
		return 1
	}))

	// combat.heal(caster_id, target_id, amount)
	// Restores HP to the target, capped at "max_hp".
	// Returns the new HP value.
	L.SetField(combat, "heal", L.NewFunction(func(L *lua.LState) int {
		_ = ecs.Entity(L.CheckNumber(1)) // caster_id (reserved)
		targetID := ecs.Entity(L.CheckNumber(2))
		amount := float64(L.CheckNumber(3))
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		hp, _ := b.ECS.GetStat(targetID, "hp")
		hp += amount
		if maxHP, ok := b.ECS.GetStat(targetID, "max_hp"); ok && maxHP > 0 && hp > maxHP {
			hp = maxHP
		}
		b.ECS.SetStat(targetID, "hp", hp)
		L.Push(lua.LNumber(hp))
		return 1
	}))

	// combat.check_hit(attacker_id, target_id) -> bool
	// Base hit chance: 80%, modified ±2% per level difference, clamped [10%, 95%].
	L.SetField(combat, "check_hit", L.NewFunction(func(L *lua.LState) int {
		attackerID := ecs.Entity(L.CheckNumber(1))
		targetID := ecs.Entity(L.CheckNumber(2))
		if b.ECS == nil {
			L.Push(lua.LTrue)
			return 1
		}
		attackerLvl, _ := b.ECS.GetStat(attackerID, "level")
		targetLvl, _ := b.ECS.GetStat(targetID, "level")
		hitChance := 0.80 + (attackerLvl-targetLvl)*0.02
		if hitChance < 0.10 {
			hitChance = 0.10
		}
		if hitChance > 0.95 {
			hitChance = 0.95
		}
		L.Push(lua.LBool(rand.Float64() < hitChance))
		return 1
	}))

	L.SetGlobal("combat", combat)
}

// --- entity.* ---

func (b *Bridge) registerEntity(L *lua.LState) {
	entity := L.NewTable()

	// entity.get_position(entity_id) -> {x, y, z, heading}
	L.SetField(entity, "get_position", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		t := L.NewTable()
		if b.ECS != nil {
			if pos, ok := b.ECS.GetPosition(id); ok {
				L.SetField(t, "x", lua.LNumber(pos.X))
				L.SetField(t, "y", lua.LNumber(pos.Y))
				L.SetField(t, "z", lua.LNumber(pos.Z))
				L.SetField(t, "heading", lua.LNumber(pos.Heading))
				L.Push(t)
				return 1
			}
		}
		// Entity has no position yet — return zero table.
		L.SetField(t, "x", lua.LNumber(0))
		L.SetField(t, "y", lua.LNumber(0))
		L.SetField(t, "z", lua.LNumber(0))
		L.SetField(t, "heading", lua.LNumber(0))
		L.Push(t)
		return 1
	}))

	// entity.set_position(entity_id, x, y, z [, heading])
	// Sets the spatial state of entity.  heading (0–255) is optional.
	L.SetField(entity, "set_position", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		x := float32(L.CheckNumber(2))
		y := float32(L.CheckNumber(3))
		z := float32(L.CheckNumber(4))
		var heading byte
		if L.GetTop() >= 5 {
			heading = byte(L.CheckNumber(5))
		}
		if b.ECS == nil {
			return 0
		}
		// Preserve existing WorldID/MapNum if already set.
		pos, ok := b.ECS.GetPosition(id)
		if !ok {
			pos = &ecs.PositionComp{}
		}
		pos.X, pos.Y, pos.Z, pos.Heading = x, y, z, heading
		b.ECS.SetPosition(id, pos)
		return 0
	}))

	// entity.get_stat(entity_id, stat_name) -> number
	L.SetField(entity, "get_stat", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		key := L.CheckString(2)
		if b.ECS != nil {
			if val, ok := b.ECS.GetStat(id, key); ok {
				L.Push(lua.LNumber(val))
				return 1
			}
		}
		L.Push(lua.LNumber(0))
		return 1
	}))

	// entity.set_stat(entity_id, stat_name, value)
	L.SetField(entity, "set_stat", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		key := L.CheckString(2)
		val := float64(L.CheckNumber(3))
		if b.ECS != nil {
			b.ECS.SetStat(id, key, val)
		}
		return 0
	}))

	// entity.get_nearby(entity_id, radius) -> {entity_id, ...}
	// Returns entity IDs within radius metres (O(n) scan over all positioned entities).
	L.SetField(entity, "get_nearby", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		radius := float32(L.CheckNumber(2))
		result := L.NewTable()
		if b.ECS != nil {
			for i, nearby := range b.ECS.GetNearby(id, radius) {
				result.RawSetInt(i+1, lua.LNumber(float64(nearby)))
			}
		}
		L.Push(result)
		return 1
	}))

	// entity.get_nearby_players(entity_id, radius) -> {entity_id, ...}  (Phase S-7)
	// Like get_nearby but filters to entities with PlayerComp. Used for chat
	// local/shout broadcast where NPCs should not receive player messages.
	L.SetField(entity, "get_nearby_players", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		radius := float32(L.CheckNumber(2))
		result := L.NewTable()
		if b.ECS != nil {
			for i, nearby := range b.ECS.GetNearbyPlayers(id, radius) {
				result.RawSetInt(i+1, lua.LNumber(float64(nearby)))
			}
		}
		L.Push(result)
		return 1
	}))

	// entity.get_all_players() -> {entity_id, ...}
	// Returns a snapshot of entity IDs for all currently connected players.
	L.SetField(entity, "get_all_players", L.NewFunction(func(L *lua.LState) int {
		result := L.NewTable()
		if b.ECS != nil {
			for i, e := range b.ECS.AllPlayers() {
				result.RawSetInt(i+1, lua.LNumber(float64(e)))
			}
		}
		L.Push(result)
		return 1
	}))

	// entity.get_all_npcs() -> {entity_id, ...}
	// Returns a snapshot of entity IDs for all spawned NPC entities.
	L.SetField(entity, "get_all_npcs", L.NewFunction(func(L *lua.LState) int {
		result := L.NewTable()
		if b.ECS != nil {
			for i, e := range b.ECS.AllNPCs() {
				result.RawSetInt(i+1, lua.LNumber(float64(e)))
			}
		}
		L.Push(result)
		return 1
	}))

	// entity.get_gateway_id(entity_id) -> gateway_seq_id or nil
	// Returns the Gateway session ID if the entity has an active PlayerComp, else nil.
	L.SetField(entity, "get_gateway_id", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		if b.ECS != nil {
			if p, ok := b.ECS.GetPlayer(id); ok {
				L.Push(lua.LNumber(float64(p.GatewaySeqID)))
				return 1
			}
		}
		L.Push(lua.LNil)
		return 1
	}))

	// entity.get_npc_template(entity_id) -> template_id  (Phase S-8)
	// Returns the NPC template ID (from NpcComp) used to dispatch dialog
	// scripts keyed by template. Returns 0 if the entity is not an NPC.
	L.SetField(entity, "get_npc_template", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		if b.ECS != nil {
			if npc, ok := b.ECS.GetNpc(id); ok {
				L.Push(lua.LNumber(float64(npc.TemplateID)))
				return 1
			}
		}
		L.Push(lua.LNumber(0))
		return 1
	}))

	L.SetGlobal("entity", entity)
}

// --- db.* ---

func (b *Bridge) registerDB(L *lua.LState) {
	db := L.NewTable()

	// db.call(proc_name, ...) -> result_table or nil, error_string
	L.SetField(db, "call", L.NewFunction(func(L *lua.LState) int {
		procName := L.CheckString(1)
		nargs := L.GetTop() - 1
		args := make([]any, nargs)
		for i := 0; i < nargs; i++ {
			args[i] = luaToGo(L.Get(i + 2))
		}

		if b.DB == nil {
			// Phase S-0: DB bridge not yet wired; return empty table
			L.Push(L.NewTable())
			return 1
		}

		rows, err := b.DB.CallSP(context.Background(), procName, args)
		if err != nil {
			L.Push(lua.LNil)
			L.Push(lua.LString(err.Error()))
			return 2
		}

		result := L.NewTable()
		for i, row := range rows {
			rowTable := L.NewTable()
			for k, v := range row {
				L.SetField(rowTable, k, goToLua(L, v))
			}
			result.RawSetInt(i+1, rowTable)
		}
		L.Push(result)
		return 1
	}))

	L.SetGlobal("db", db)
}

// --- player.* ---

func (b *Bridge) registerPlayer(L *lua.LState) {
	player := L.NewTable()

	// player.send_packet(gateway_seq_id, opcode, payload_string)
	// Sends an SM_* packet to the client session identified by gateway_seq_id.
	// payload_string is a raw binary Lua string (use bytes.new() to build it).
	L.SetField(player, "send_packet", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		opcode := uint16(L.CheckNumber(2))
		payload := []byte(L.CheckString(3))
		if b.Sender == nil {
			return 0
		}
		if err := b.Sender.SendToPlayer(gwSeqID, opcode, payload); err != nil {
			b.logger().Warn("[Lua] player.send_packet failed",
				"gateway_seq_id", gwSeqID, "opcode", opcode, "err", err)
		}
		return 0
	}))

	// player.send_message(gateway_seq_id, message_string)
	// Sends a SYSTEM-channel chat message (SM_CHAT 0x48, channel byte 0x0B).
	// Payload: channel(byte), sender_name_utf16_null, message_utf16_null.
	// NOTE: channel byte and SM_CHAT format are unverified; adjust after packet capture.
	L.SetField(player, "send_message", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		msg := L.CheckString(2)
		if b.Sender == nil {
			return 0
		}
		var payload []byte
		payload = append(payload, 0x0B) // SYSTEM channel
		payload = append(payload, 0x00, 0x00) // empty sender name (UTF-16 LE null-term)
		for _, r := range msg {
			u := uint16(r)
			payload = append(payload, byte(u), byte(u>>8))
		}
		payload = append(payload, 0x00, 0x00) // message null-terminator
		if err := b.Sender.SendToPlayer(gwSeqID, 0x48, payload); err != nil {
			b.logger().Warn("[Lua] player.send_message failed",
				"gateway_seq_id", gwSeqID, "err", err)
		}
		return 0
	}))

	// player.set_name(gateway_seq_id, char_name)  (Phase S-7)
	// Stores the display name on PlayerComp.CharName for whisper/group lookup.
	// Called by cm_enter_world.lua once the DB returns the character record.
	L.SetField(player, "set_name", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		name := L.CheckString(2)
		if b.ECS == nil {
			return 0
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			return 0
		}
		if comp, ok := b.ECS.GetPlayer(eid); ok {
			comp.CharName = name
		}
		return 0
	}))

	// player.get_name(gateway_seq_id) -> string  (Phase S-7)
	// Returns the character's display name, or empty string if not set.
	L.SetField(player, "get_name", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		if b.ECS == nil {
			L.Push(lua.LString(""))
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LString(""))
			return 1
		}
		if comp, ok := b.ECS.GetPlayer(eid); ok {
			L.Push(lua.LString(comp.CharName))
			return 1
		}
		L.Push(lua.LString(""))
		return 1
	}))

	// player.find_by_name(char_name) -> entity_id  (Phase S-7)
	// Returns the entity ID (number) of an online player, or 0 if not found.
	// Used by chat whisper routing to resolve a recipient name.
	L.SetField(player, "find_by_name", L.NewFunction(func(L *lua.LState) int {
		name := L.CheckString(1)
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		if eid, ok := b.ECS.FindPlayerByName(name); ok {
			L.Push(lua.LNumber(float64(eid)))
			return 1
		}
		L.Push(lua.LNumber(0))
		return 1
	}))

	// player.add_item(gateway_seq_id, item_id, count)
	// Looks up char_id from ECS, calls aion_AddItemUser SP.
	// NOTE: SP name "aion_AddItemUser" must be verified against deployed procedures.
	L.SetField(player, "add_item", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		itemID := int32(L.CheckNumber(2))
		count := int32(L.CheckNumber(3))
		if b.ECS == nil || b.DB == nil {
			return 0
		}
		entityID, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			return 0
		}
		charID, ok := b.ECS.GetStat(entityID, "char_id")
		if !ok {
			return 0
		}
		if _, err := b.DB.CallSP(context.Background(), "aion_AddItemUser",
			[]any{int64(charID), itemID, count}); err != nil {
			b.logger().Warn("[Lua] player.add_item failed",
				"char_id", charID, "item_id", itemID, "err", err)
		}
		return 0
	}))

	// player.remove_item(gateway_seq_id, item_id, count) -> bool
	// Calls aion_RemoveItemUser SP; returns true on success.
	// NOTE: SP name must be verified against deployed procedures.
	L.SetField(player, "remove_item", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		itemID := int32(L.CheckNumber(2))
		count := int32(L.CheckNumber(3))
		if b.ECS == nil || b.DB == nil {
			L.Push(lua.LFalse)
			return 1
		}
		entityID, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LFalse)
			return 1
		}
		charID, ok := b.ECS.GetStat(entityID, "char_id")
		if !ok {
			L.Push(lua.LFalse)
			return 1
		}
		_, err := b.DB.CallSP(context.Background(), "aion_RemoveItemUser",
			[]any{int64(charID), itemID, count})
		L.Push(lua.LBool(err == nil))
		return 1
	}))

	// player.get_inventory(gateway_seq_id) -> items_table
	// Calls aion_GetItemsByUser SP; returns array of {item_id, count, slot, ...} rows.
	// NOTE: SP name must be verified against deployed procedures.
	L.SetField(player, "get_inventory", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		result := L.NewTable()
		if b.ECS == nil || b.DB == nil {
			L.Push(result)
			return 1
		}
		entityID, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(result)
			return 1
		}
		charID, ok := b.ECS.GetStat(entityID, "char_id")
		if !ok {
			L.Push(result)
			return 1
		}
		rows, err := b.DB.CallSP(context.Background(), "aion_GetItemsByUser",
			[]any{int64(charID)})
		if err != nil {
			b.logger().Warn("[Lua] player.get_inventory failed",
				"char_id", charID, "err", err)
			L.Push(result)
			return 1
		}
		for i, row := range rows {
			rowTable := L.NewTable()
			for k, v := range row {
				L.SetField(rowTable, k, goToLua(L, v))
			}
			result.RawSetInt(i+1, rowTable)
		}
		L.Push(result)
		return 1
	}))

	// player.add_exp(gateway_seq_id, exp_amount) -> new_level
	// Awards exp_amount EXP to the character via aion_AddExpUser SP.
	// Returns the character's new level (0 on error).
	// NOTE: SP return column name "lev" is assumed — verify against deployed procedures.
	L.SetField(player, "add_exp", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		expAmount := int64(L.CheckNumber(2))
		if b.ECS == nil || b.DB == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		entityID, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LNumber(0))
			return 1
		}
		charID, ok := b.ECS.GetStat(entityID, "char_id")
		if !ok {
			L.Push(lua.LNumber(0))
			return 1
		}
		rows, err := b.DB.CallSP(context.Background(), "aion_AddExpUser",
			[]any{int64(charID), expAmount})
		if err != nil {
			b.logger().Warn("[Lua] player.add_exp failed",
				"char_id", charID, "err", err)
			// Fall back to current ECS level on SP failure.
			lvl, _ := b.ECS.GetStat(entityID, "level")
			L.Push(lua.LNumber(lvl))
			return 1
		}
		// SP should return a row with the new level.
		if len(rows) > 0 {
			if lv := rows[0]["lev"]; lv != nil {
				L.Push(goToLua(L, lv))
				return 1
			}
		}
		// SP returned no level column; fall back to current ECS value.
		lvl, _ := b.ECS.GetStat(entityID, "level")
		L.Push(lua.LNumber(lvl))
		return 1
	}))

	// player.get_kinah(gateway_seq_id) -> number  (Phase S-8)
	// Reads the cached "kinah" ECS stat — updated by buy/sell operations and
	// by aion_GetKinahUser SP on world entry. Returns 0 if not set.
	L.SetField(player, "get_kinah", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LNumber(0))
			return 1
		}
		k, _ := b.ECS.GetStat(eid, "kinah")
		L.Push(lua.LNumber(k))
		return 1
	}))

	// player.add_kinah(gateway_seq_id, amount) -> bool  (Phase S-8)
	// Adds amount to the player's kinah balance via aion_AddKinahUser SP.
	// Updates ECS cache on success. Returns true on SP success.
	// NOTE: SP name "aion_AddKinahUser" unverified — adjust after schema check.
	L.SetField(player, "add_kinah", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		amount := int64(L.CheckNumber(2))
		if b.ECS == nil {
			L.Push(lua.LFalse)
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LFalse)
			return 1
		}
		// Update cached stat unconditionally; DB call is best-effort.
		cur, _ := b.ECS.GetStat(eid, "kinah")
		newBalance := cur + float64(amount)
		b.ECS.SetStat(eid, "kinah", newBalance)

		if b.DB != nil {
			if charID, hasChar := b.ECS.GetStat(eid, "char_id"); hasChar {
				if _, err := b.DB.CallSP(context.Background(),
					"aion_AddKinahUser", []any{int64(charID), amount}); err != nil {
					b.logger().Warn("[Lua] player.add_kinah SP failed",
						"char_id", charID, "err", err)
					L.Push(lua.LFalse)
					return 1
				}
			}
		}
		L.Push(lua.LTrue)
		return 1
	}))

	// player.spend_kinah(gateway_seq_id, amount) -> bool  (Phase S-8)
	// Atomically checks balance and deducts amount. Returns false if the
	// player does not have enough kinah; no DB call in that case.
	L.SetField(player, "spend_kinah", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		amount := int64(L.CheckNumber(2))
		if amount <= 0 {
			L.Push(lua.LFalse)
			return 1
		}
		if b.ECS == nil {
			L.Push(lua.LFalse)
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LFalse)
			return 1
		}
		cur, _ := b.ECS.GetStat(eid, "kinah")
		if cur < float64(amount) {
			L.Push(lua.LFalse)
			return 1
		}
		b.ECS.SetStat(eid, "kinah", cur-float64(amount))

		if b.DB != nil {
			if charID, hasChar := b.ECS.GetStat(eid, "char_id"); hasChar {
				if _, err := b.DB.CallSP(context.Background(),
					"aion_AddKinahUser", []any{int64(charID), -amount}); err != nil {
					b.logger().Warn("[Lua] player.spend_kinah SP failed",
						"char_id", charID, "err", err)
					// Roll back cache on DB failure.
					b.ECS.SetStat(eid, "kinah", cur)
					L.Push(lua.LFalse)
					return 1
				}
			}
		}
		L.Push(lua.LTrue)
		return 1
	}))

	// player.get_ap(gateway_seq_id) -> number  (Phase S-11)
	// Reads the cached "abyss_points" ECS stat. Populated by cm_enter_world via
	// aion_GetAbyssPointUser SP (if available) and updated by PvP kill rewards.
	L.SetField(player, "get_ap", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LNumber(0))
			return 1
		}
		ap, _ := b.ECS.GetStat(eid, "abyss_points")
		L.Push(lua.LNumber(ap))
		return 1
	}))

	// player.add_ap(gateway_seq_id, amount) -> bool  (Phase S-11)
	// Adds abyss points via aion_AddAbyssPointUser SP and updates ECS cache.
	// Negative amounts are allowed (deduction). Cache is rolled back on SP
	// failure so callers see a consistent view.
	// NOTE: SP name "aion_AddAbyssPointUser" unverified — adjust after schema check.
	L.SetField(player, "add_ap", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		amount := int64(L.CheckNumber(2))
		if b.ECS == nil {
			L.Push(lua.LFalse)
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LFalse)
			return 1
		}
		cur, _ := b.ECS.GetStat(eid, "abyss_points")
		newBalance := cur + float64(amount)
		if newBalance < 0 {
			newBalance = 0
		}
		b.ECS.SetStat(eid, "abyss_points", newBalance)

		if b.DB != nil {
			if charID, hasChar := b.ECS.GetStat(eid, "char_id"); hasChar {
				if _, err := b.DB.CallSP(context.Background(),
					"aion_AddAbyssPointUser", []any{int64(charID), amount}); err != nil {
					b.logger().Warn("[Lua] player.add_ap SP failed",
						"char_id", charID, "err", err)
					// Roll back cache on DB failure.
					b.ECS.SetStat(eid, "abyss_points", cur)
					L.Push(lua.LFalse)
					return 1
				}
			}
		}
		L.Push(lua.LTrue)
		return 1
	}))

	// player.spend_ap(gateway_seq_id, amount) -> bool  (Phase S-11)
	// Atomic check-and-deduct for abyss-point purchases (Abyss equipment NPCs).
	// Returns false without any DB call if balance is insufficient.
	L.SetField(player, "spend_ap", L.NewFunction(func(L *lua.LState) int {
		gwSeqID := uint64(L.CheckNumber(1))
		amount := int64(L.CheckNumber(2))
		if amount <= 0 {
			L.Push(lua.LFalse)
			return 1
		}
		if b.ECS == nil {
			L.Push(lua.LFalse)
			return 1
		}
		eid, ok := b.ECS.GetEntityBySeqID(gwSeqID)
		if !ok {
			L.Push(lua.LFalse)
			return 1
		}
		cur, _ := b.ECS.GetStat(eid, "abyss_points")
		if cur < float64(amount) {
			L.Push(lua.LFalse)
			return 1
		}
		b.ECS.SetStat(eid, "abyss_points", cur-float64(amount))

		if b.DB != nil {
			if charID, hasChar := b.ECS.GetStat(eid, "char_id"); hasChar {
				if _, err := b.DB.CallSP(context.Background(),
					"aion_AddAbyssPointUser", []any{int64(charID), -amount}); err != nil {
					b.logger().Warn("[Lua] player.spend_ap SP failed",
						"char_id", charID, "err", err)
					// Roll back cache on DB failure.
					b.ECS.SetStat(eid, "abyss_points", cur)
					L.Push(lua.LFalse)
					return 1
				}
			}
		}
		L.Push(lua.LTrue)
		return 1
	}))

	L.SetGlobal("player", player)
}

// --- world.* ---

func (b *Bridge) registerWorld(L *lua.LState) {
	world := L.NewTable()

	// world.spawn_npc(template_id, x, y, z) -> entity_id
	// Creates a new NPC entity in the ECS at the given position.
	L.SetField(world, "spawn_npc", L.NewFunction(func(L *lua.LState) int {
		templateID := int32(L.CheckNumber(1))
		x := float32(L.CheckNumber(2))
		y := float32(L.CheckNumber(3))
		z := float32(L.CheckNumber(4))
		if b.ECS == nil {
			L.Push(lua.LNumber(0))
			return 1
		}
		e := b.ECS.NewEntity()
		b.ECS.SetNpc(e, &ecs.NpcComp{TemplateID: templateID})
		b.ECS.SetPosition(e, &ecs.PositionComp{X: x, Y: y, Z: z})
		L.Push(lua.LNumber(float64(e)))
		return 1
	}))

	// world.despawn(entity_id) — removes the entity and all its components.
	L.SetField(world, "despawn", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		if b.ECS != nil {
			b.ECS.DestroyEntity(id)
		}
		return 0
	}))

	// world.get_zone(entity_id) -> zone_id
	// Returns the WorldID stored in the entity's PositionComp (0 if unset).
	L.SetField(world, "get_zone", L.NewFunction(func(L *lua.LState) int {
		id := ecs.Entity(L.CheckNumber(1))
		if b.ECS != nil {
			if pos, ok := b.ECS.GetPosition(id); ok {
				L.Push(lua.LNumber(pos.WorldID))
				return 1
			}
		}
		L.Push(lua.LNumber(0))
		return 1
	}))

	L.SetGlobal("world", world)
}

// --- config.* ---

func (b *Bridge) registerConfig(L *lua.LState) {
	cfg := L.NewTable()

	// config.rates(category, key) -> number
	// Example: config.rates("drop", "normal") -> 2.0
	L.SetField(cfg, "rates", L.NewFunction(func(L *lua.LState) int {
		// TODO Phase S-0: connect to hot-reload rates config
		// Returning 1.0 as default until wired.
		L.Push(lua.LNumber(1.0))
		return 1
	}))

	// config.get(section, key) -> value
	L.SetField(cfg, "get", L.NewFunction(func(L *lua.LState) int {
		// TODO Phase S-1: connect to TOML config loader
		L.Push(lua.LNil)
		return 1
	}))

	L.SetGlobal("config", cfg)
}

// --- bytes.* ---

// registerBytes exposes binary buffer construction and parsing to Lua.
//
// Writer API:  local buf = bytes.new()
//                buf:write_byte(n)
//                buf:write_int16(n)
//                buf:write_int32(n)
//                buf:write_int64(n)
//                buf:write_float32(n)
//                buf:write_string(s)          -- raw bytes
//                buf:write_string_utf16(s)    -- UTF-16 LE, null-terminated
//                buf:to_string() -> string
//                buf:len() -> int
//
// Reader API:  local r = bytes.reader(payload_string)
//                r:read_byte()   -> int
//                r:read_int16()  -> int
//                r:read_int32()  -> int
//                r:read_int64()  -> int
//                r:read_float32() -> number
//                r:read_string(n) -> string   -- n raw bytes
func (b *Bridge) registerBytes(L *lua.LState) {
	mod := L.NewTable()

	// bytes.new() returns a write-only byte buffer.
	L.SetField(mod, "new", L.NewFunction(func(L *lua.LState) int {
		var buf []byte
		obj := L.NewTable()

		// NOTE: All writer methods are called via Lua colon syntax (buf:method(arg)),
		// so the Lua VM passes the receiver table as arg index 1 and the actual data
		// value as arg index 2.  Use index 2 for all data reads.
		L.SetField(obj, "write_byte", L.NewFunction(func(L *lua.LState) int {
			buf = append(buf, byte(L.CheckNumber(2)))
			return 0
		}))
		L.SetField(obj, "write_int16", L.NewFunction(func(L *lua.LState) int {
			v := uint16(int16(L.CheckNumber(2)))
			buf = append(buf, byte(v), byte(v>>8))
			return 0
		}))
		L.SetField(obj, "write_int32", L.NewFunction(func(L *lua.LState) int {
			v := uint32(int32(L.CheckNumber(2)))
			var b4 [4]byte
			binary.LittleEndian.PutUint32(b4[:], v)
			buf = append(buf, b4[:]...)
			return 0
		}))
		L.SetField(obj, "write_int64", L.NewFunction(func(L *lua.LState) int {
			v := uint64(int64(L.CheckNumber(2)))
			var b8 [8]byte
			binary.LittleEndian.PutUint64(b8[:], v)
			buf = append(buf, b8[:]...)
			return 0
		}))
		L.SetField(obj, "write_float32", L.NewFunction(func(L *lua.LState) int {
			bits := math.Float32bits(float32(L.CheckNumber(2)))
			var b4 [4]byte
			binary.LittleEndian.PutUint32(b4[:], bits)
			buf = append(buf, b4[:]...)
			return 0
		}))
		L.SetField(obj, "write_string", L.NewFunction(func(L *lua.LState) int {
			buf = append(buf, []byte(L.CheckString(2))...)
			return 0
		}))
		// write_string_utf16: encodes the string as UTF-16 LE + null terminator.
		L.SetField(obj, "write_string_utf16", L.NewFunction(func(L *lua.LState) int {
			for _, r := range L.CheckString(2) {
				u := uint16(r)
				buf = append(buf, byte(u), byte(u>>8))
			}
			buf = append(buf, 0x00, 0x00) // null terminator
			return 0
		}))
		L.SetField(obj, "to_string", L.NewFunction(func(L *lua.LState) int {
			L.Push(lua.LString(buf))
			return 1
		}))
		L.SetField(obj, "len", L.NewFunction(func(L *lua.LState) int {
			L.Push(lua.LNumber(len(buf)))
			return 1
		}))

		L.Push(obj)
		return 1
	}))

	// bytes.reader(s) returns a read-cursor over a binary payload string.
	L.SetField(mod, "reader", L.NewFunction(func(L *lua.LState) int {
		data := []byte(L.CheckString(1))
		pos := 0
		obj := L.NewTable()

		readN := func(n int) ([]byte, bool) {
			if pos+n > len(data) {
				return nil, false
			}
			chunk := data[pos : pos+n]
			pos += n
			return chunk, true
		}

		L.SetField(obj, "read_byte", L.NewFunction(func(L *lua.LState) int {
			b, ok := readN(1)
			if !ok {
				L.Push(lua.LNumber(0))
			} else {
				L.Push(lua.LNumber(b[0]))
			}
			return 1
		}))
		L.SetField(obj, "read_int16", L.NewFunction(func(L *lua.LState) int {
			b, ok := readN(2)
			if !ok {
				L.Push(lua.LNumber(0))
			} else {
				L.Push(lua.LNumber(int16(binary.LittleEndian.Uint16(b))))
			}
			return 1
		}))
		L.SetField(obj, "read_int32", L.NewFunction(func(L *lua.LState) int {
			b, ok := readN(4)
			if !ok {
				L.Push(lua.LNumber(0))
			} else {
				L.Push(lua.LNumber(int32(binary.LittleEndian.Uint32(b))))
			}
			return 1
		}))
		L.SetField(obj, "read_int64", L.NewFunction(func(L *lua.LState) int {
			b, ok := readN(8)
			if !ok {
				L.Push(lua.LNumber(0))
			} else {
				L.Push(lua.LNumber(float64(int64(binary.LittleEndian.Uint64(b)))))
			}
			return 1
		}))
		L.SetField(obj, "read_float32", L.NewFunction(func(L *lua.LState) int {
			b, ok := readN(4)
			if !ok {
				L.Push(lua.LNumber(0))
			} else {
				bits := binary.LittleEndian.Uint32(b)
				L.Push(lua.LNumber(math.Float32frombits(bits)))
			}
			return 1
		}))
		// read_string is called via colon syntax (r:read_string(n)); self is arg 1,
		// n is arg 2.
		L.SetField(obj, "read_string", L.NewFunction(func(L *lua.LState) int {
			n := int(L.CheckNumber(2))
			b, ok := readN(n)
			if !ok {
				L.Push(lua.LString(""))
			} else {
				L.Push(lua.LString(b))
			}
			return 1
		}))
		L.SetField(obj, "remaining", L.NewFunction(func(L *lua.LState) int {
			L.Push(lua.LNumber(len(data) - pos))
			return 1
		}))

		L.Push(obj)
		return 1
	}))

	L.SetGlobal("bytes", mod)
}

// --- jobq.* ---

// registerJobq exposes two Lua globals backed by the JobQueue interface:
//
//	jobq.enqueue(kind, args_table [, delay_ms]) -> bool, err_msg
//	  kind is a string like "aion58.cron.daily_reset" that the World Engine
//	  binds to a handler via internal/jobq workers.go.  args_table is any
//	  Lua table; it is serialised to a JSON byte string.  delay_ms is an
//	  optional millisecond delay — ignored by Phase S-13 (kept for API
//	  forward-compat; the asynq.ProcessIn Option lands in a follow-up).
//
// When Jobs is nil (no Redis) the call returns (false, "disabled") so Lua
// scripts can branch without the whole script crashing.
func (b *Bridge) registerJobq(L *lua.LState) {
	jq := L.NewTable()

	L.SetField(jq, "enqueue", L.NewFunction(func(L *lua.LState) int {
		kind := L.CheckString(1)
		argsTbl := L.OptTable(2, nil)
		// Third arg is an optional delay in seconds. When > 0 we dispatch via
		// EnqueueKindIn so asynq schedules the task for future processing
		// (Phase S-16: auction expiry is the first real consumer).
		delaySec := float64(L.OptNumber(3, 0))

		if b.Jobs == nil {
			L.Push(lua.LFalse)
			L.Push(lua.LString("disabled"))
			return 2
		}

		// Convert the Lua table into a JSON byte slice.  Keep this tolerant:
		// if argsTbl is nil, emit an empty object.
		payload := []byte("{}")
		if argsTbl != nil {
			converted := luaTableToGo(argsTbl)
			js, err := marshalJSONSafe(converted)
			if err != nil {
				L.Push(lua.LFalse)
				L.Push(lua.LString(err.Error()))
				return 2
			}
			payload = js
		}

		var err error
		if delaySec > 0 {
			delay := time.Duration(delaySec * float64(time.Second))
			err = b.Jobs.EnqueueKindIn(context.Background(), kind, payload, delay)
		} else {
			err = b.Jobs.EnqueueKind(context.Background(), kind, payload)
		}
		if err != nil {
			b.logger().Warn("[Lua] jobq.enqueue failed", "kind", kind, "err", err)
			L.Push(lua.LFalse)
			L.Push(lua.LString(err.Error()))
			return 2
		}
		L.Push(lua.LTrue)
		return 1
	}))

	L.SetGlobal("jobq", jq)
}

// luaTableToGo recursively converts a Lua table to a Go map[string]any or
// []any depending on whether the keys are string or sequential integer.
// This mirrors the luaToGo path used by db.call args but walks nested tables.
func luaTableToGo(t *lua.LTable) any {
	// Detect array-like tables (dense 1-indexed integer keys).
	maxN := t.Len()
	if maxN > 0 {
		arr := make([]any, 0, maxN)
		for i := 1; i <= maxN; i++ {
			arr = append(arr, luaValueToGo(t.RawGetInt(i)))
		}
		return arr
	}
	m := make(map[string]any)
	t.ForEach(func(k, v lua.LValue) {
		key, ok := k.(lua.LString)
		if !ok {
			return
		}
		m[string(key)] = luaValueToGo(v)
	})
	return m
}

func luaValueToGo(v lua.LValue) any {
	switch val := v.(type) {
	case lua.LBool:
		return bool(val)
	case lua.LNumber:
		return float64(val)
	case lua.LString:
		return string(val)
	case *lua.LTable:
		return luaTableToGo(val)
	case *lua.LNilType:
		return nil
	default:
		return nil
	}
}

// marshalJSONSafe wraps encoding/json.Marshal for the jobq binding.
// Defined as a var so tests can substitute a failing marshaller.
var marshalJSONSafe = func(v any) ([]byte, error) {
	return jsonMarshal(v)
}

// --- type conversion helpers ---

// luaToGo converts a Lua value to a Go value suitable for use as a SP arg.
func luaToGo(v lua.LValue) any {
	switch val := v.(type) {
	case lua.LBool:
		return bool(val)
	case lua.LNumber:
		return float64(val)
	case lua.LString:
		return string(val)
	case *lua.LNilType:
		return nil
	default:
		return nil
	}
}

// goToLua converts a Go value (from a SP result row) to a Lua value.
func goToLua(L *lua.LState, v any) lua.LValue {
	if v == nil {
		return lua.LNil
	}
	switch val := v.(type) {
	case bool:
		if val {
			return lua.LTrue
		}
		return lua.LFalse
	case int:
		return lua.LNumber(val)
	case int32:
		return lua.LNumber(val)
	case int64:
		return lua.LNumber(val)
	case float32:
		return lua.LNumber(val)
	case float64:
		return lua.LNumber(val)
	case string:
		return lua.LString(val)
	case []byte:
		return lua.LString(val)
	default:
		return lua.LString(fmt.Sprintf("%v", val))
	}
}

func (b *Bridge) logger() *slog.Logger {
	if b.Logger != nil {
		return b.Logger
	}
	return slog.Default()
}
