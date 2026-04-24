package main

import (
	"context"
	"encoding/binary"
	"fmt"
	"log/slog"
	"math"
	"sync"

	"aion58/internal/aionproto"
	"aion58/internal/ecs"
	"aion58/internal/ipc"
	"aion58/internal/luahost"

	lua "github.com/yuin/gopher-lua"
)

// Dispatcher bridges the NATS event bus, the ECS world, and the Lua VM pool.
//
// Lifecycle per player:
//
//	player.enter  → create ECS entity + subscribe player.cm.{id} + send char list
//	player.cm.*   → dispatch CM_* opcode to Lua handler
//	player.leave  → cancel subscription + destroy ECS entity
type Dispatcher struct {
	nc       *ipc.Client
	vmPool   *luahost.VMPool
	world    *ecs.World
	db       luahost.DBBridge
	sessions sync.Map // key: uint64(gatewaySeqID) → *playerSession
}

// playerSession holds runtime state for one active game-port connection.
type playerSession struct {
	entityID     ecs.Entity
	accountID    int64
	account      string
	gatewaySeqID uint64
	unsub        func() // cancels player.cm.{id} NATS subscription
}

// newDispatcher returns a ready Dispatcher.  Pass nil for db to disable
// character-list SP calls (dev mode without PostgreSQL).
func newDispatcher(nc *ipc.Client, vmPool *luahost.VMPool, world *ecs.World, db luahost.DBBridge) *Dispatcher {
	return &Dispatcher{nc: nc, vmPool: vmPool, world: world, db: db}
}

// onPlayerEnter is called when a player.enter event arrives from the Gateway.
func (d *Dispatcher) onPlayerEnter(ev ipc.PlayerEnterEvent) {
	// 1. Register ECS entity.
	entityID := d.world.NewEntity()
	d.world.SetPlayer(entityID, &ecs.PlayerComp{
		AccountID:    ev.AccountID,
		Account:      ev.Account,
		GatewaySeqID: ev.GatewaySeqID,
		RemoteAddr:   ev.RemoteAddr,
	})

	// 2. Subscribe to CM_* packets for this session.
	cmSubject := fmt.Sprintf("%s.%d", ipc.SubjectPlayerCM, ev.GatewaySeqID)
	unsub, err := ipc.Subscribe[ipc.PacketEvent](d.nc, cmSubject,
		func(pkt ipc.PacketEvent) {
			d.dispatchCM(ev.GatewaySeqID, entityID, pkt)
		})
	if err != nil {
		slog.Warn("world: subscribe CM channel",
			"gateway_seq_id", ev.GatewaySeqID, "err", err)
		unsub = func() {}
	}

	d.sessions.Store(ev.GatewaySeqID, &playerSession{
		entityID:     entityID,
		accountID:    ev.AccountID,
		account:      ev.Account,
		gatewaySeqID: ev.GatewaySeqID,
		unsub:        unsub,
	})

	// 3. Send the character list immediately (AION protocol: no request needed).
	d.sendCharacterList(ev.AccountID, ev.GatewaySeqID)

	slog.Info("world: player session started",
		"account", ev.Account,
		"gateway_seq_id", ev.GatewaySeqID,
		"entity_id", entityID,
		"online", d.world.Count())
}

// onPlayerLeave is called when a player.leave event arrives from the Gateway.
func (d *Dispatcher) onPlayerLeave(ev ipc.PlayerLeaveEvent) {
	val, ok := d.sessions.LoadAndDelete(ev.GatewaySeqID)
	if !ok {
		return
	}
	sess := val.(*playerSession)
	sess.unsub()
	d.world.DestroyEntity(sess.entityID)
	slog.Info("world: player session ended",
		"account", sess.account,
		"gateway_seq_id", ev.GatewaySeqID,
		"reason", ev.Reason,
		"online", d.world.Count())
}

// dispatchCM routes a CM_* packet to the registered Lua handler.
// Runs on the NATS dispatcher goroutine; VM is acquired from the pool.
func (d *Dispatcher) dispatchCM(gatewaySeqID uint64, entityID ecs.Entity, ev ipc.PacketEvent) {
	vm := d.vmPool.Acquire()
	defer d.vmPool.Release(vm)

	// Build a player context table passed to every Lua handler.
	ctx := vm.NewTable()
	vm.SetField(ctx, "gateway_seq_id", lua.LNumber(float64(gatewaySeqID)))
	vm.SetField(ctx, "entity_id", lua.LNumber(float64(entityID)))
	if p, ok := d.world.GetPlayer(entityID); ok {
		vm.SetField(ctx, "account_id", lua.LNumber(float64(p.AccountID)))
		vm.SetField(ctx, "account", lua.LString(p.Account))
	}

	fn := vm.GetGlobal("dispatch_packet")
	if fn == lua.LNil {
		// No Lua router loaded yet — normal during early startup.
		return
	}

	err := vm.CallByParam(lua.P{
		Fn:      fn,
		NRet:    0,
		Protect: true,
	}, lua.LNumber(ev.Opcode), ctx, lua.LString(ev.Payload))
	if err != nil {
		slog.Warn("world: CM dispatch error",
			"opcode", fmt.Sprintf("0x%04X", ev.Opcode),
			"gateway_seq_id", gatewaySeqID,
			"err", err)
	}
}

// onTick is called every game loop tick at worldCfg.Server.TickRate.
// Delegates to the Lua on_tick(tick) global if defined by event scripts.
func (d *Dispatcher) onTick(tick int64) {
	d.callLua("on_tick", tick)
}

// callLua calls a named Lua global function with arbitrary Go arguments.
// Used for server-initiated events (e.g., send_character_list on login).
func (d *Dispatcher) callLua(fnName string, args ...any) {
	vm := d.vmPool.Acquire()
	defer d.vmPool.Release(vm)

	fn := vm.GetGlobal(fnName)
	if fn == lua.LNil {
		return
	}
	luaArgs := make([]lua.LValue, len(args))
	for i, a := range args {
		luaArgs[i] = goArgToLua(a)
	}
	if err := vm.CallByParam(lua.P{Fn: fn, NRet: 0, Protect: true}, luaArgs...); err != nil {
		slog.Warn("world: Lua call error", "fn", fnName, "err", err)
	}
}

func goArgToLua(a any) lua.LValue {
	switch v := a.(type) {
	case int:
		return lua.LNumber(v)
	case int32:
		return lua.LNumber(v)
	case int64:
		return lua.LNumber(float64(v))
	case uint64:
		return lua.LNumber(float64(v))
	case float64:
		return lua.LNumber(v)
	case string:
		return lua.LString(v)
	case bool:
		if v {
			return lua.LTrue
		}
		return lua.LFalse
	default:
		return lua.LNil
	}
}

// SendToPlayer implements luahost.PacketSender.
// Publishes a PacketEvent to world.sm.{gatewaySeqID} so the Gateway can
// forward it to the client.
func (d *Dispatcher) SendToPlayer(gatewaySeqID uint64, opcode uint16, payload []byte) error {
	subject := fmt.Sprintf("%s.%d", ipc.SubjectWorldSM, gatewaySeqID)
	return d.nc.Publish(subject, ipc.PacketEvent{
		GatewaySeqID: gatewaySeqID,
		Opcode:       opcode,
		Payload:      payload,
	})
}

// --- Character list ---

// sendCharacterList fetches all characters for accountID and sends
// SM_CHARACTER_LIST to the client via the Gateway.
//
// Protocol: SM_CHARACTER_LIST (0x10) is sent immediately after
// CM_SESSION_CONFIRM is accepted — no request from client is needed.
func (d *Dispatcher) sendCharacterList(accountID int64, gatewaySeqID uint64) {
	var payload []byte
	payload = append(payload, 0) // server_index
	payload = append(payload, 8) // max_slots (8 for 5.8)

	count := byte(0)
	countIdx := len(payload)
	payload = append(payload, 0) // placeholder: character count

	if d.db != nil {
		idRows, err := d.db.CallSP(context.Background(), "aion_GetCharIdList", []any{accountID})
		if err != nil {
			slog.Warn("world: aion_GetCharIdList failed", "account_id", accountID, "err", err)
		} else {
			for _, idRow := range idRows {
				charID, ok := rowInt32(idRow, "char_id")
				if !ok {
					continue
				}
				infoRows, err := d.db.CallSP(context.Background(), "aion_GetCharInfo_20160818", []any{charID})
				if err != nil || len(infoRows) == 0 {
					continue
				}
				appendCharEntry(&payload, int32(charID), int32(accountID), infoRows[0])
				count++
			}
		}
	}
	payload[countIdx] = count

	subject := fmt.Sprintf("%s.%d", ipc.SubjectWorldSM, gatewaySeqID)
	if err := d.nc.Publish(subject, ipc.PacketEvent{
		GatewaySeqID: gatewaySeqID,
		Opcode:       aionproto.SM_CHARACTER_LIST,
		Payload:      payload,
	}); err != nil {
		slog.Warn("world: send character list failed",
			"gateway_seq_id", gatewaySeqID, "err", err)
	}

	slog.Info("world: sent character list",
		"account_id", accountID,
		"count", count,
		"gateway_seq_id", gatewaySeqID)
}

// appendCharEntry serialises one character row into the SM_CHARACTER_LIST payload.
// Field order matches the AION 5.8 client expectation derived from the NCSoft
// aion_GetCharInfo_20160818 result set.
func appendCharEntry(buf *[]byte, charID, accountID int32, row map[string]any) {
	// char_id + account_id
	appendInt32(buf, charID)
	appendInt32(buf, accountID)

	// Name (UTF-16 LE null-terminated)
	name, _ := row["user_id"].(string)
	for _, r := range name {
		u := uint16(r)
		*buf = append(*buf, byte(u), byte(u>>8))
	}
	*buf = append(*buf, 0x00, 0x00) // null terminator

	// race, class, gender, level
	*buf = append(*buf, rowByte(row, "race"))
	*buf = append(*buf, rowByte(row, "class"))
	*buf = append(*buf, rowByte(row, "gender"))
	*buf = append(*buf, rowByte(row, "lev"))

	// World position
	appendInt32(buf, rowInt32Safe(row, "world"))
	appendInt32(buf, rowInt32Safe(row, "world_map_number"))
	appendFloat32(buf, rowFloat32(row, "xlocation"))
	appendFloat32(buf, rowFloat32(row, "ylocation"))
	appendFloat32(buf, rowFloat32(row, "zlocation"))
	*buf = append(*buf, rowByte(row, "dir"))

	// Experience (int64)
	appendInt64(buf, rowInt64(row, "exp"))

	// HP / MP / Flight points
	appendInt32(buf, rowInt32Safe(row, "now_hit"))
	appendInt32(buf, rowInt32Safe(row, "now_mana"))
	appendInt32(buf, rowInt32Safe(row, "now_flight"))

	// Pending-delete timestamp
	appendInt32(buf, rowInt32Safe(row, "delete_date"))

	// Appearance — face / hair colours
	appendInt32(buf, rowInt32Safe(row, "head_face_color"))
	appendInt32(buf, rowInt32Safe(row, "head_hair_color"))
	appendInt32(buf, rowInt32Safe(row, "head_eye_color"))
	appendInt32(buf, rowInt32Safe(row, "head_lip_color"))
	*buf = append(*buf, rowByte(row, "head_face_type"))
	*buf = append(*buf, rowByte(row, "head_hair_type"))
	*buf = append(*buf, rowByte(row, "head_voice_type"))
	*buf = append(*buf, rowByte(row, "head_feat_type1"))
	*buf = append(*buf, rowByte(row, "head_feat_type2"))
}

// --- row value helpers ---

func rowInt32(row map[string]any, key string) (int64, bool) {
	v, ok := row[key]
	if !ok || v == nil {
		return 0, false
	}
	switch val := v.(type) {
	case int32:
		return int64(val), true
	case int64:
		return val, true
	case float64:
		return int64(val), true
	}
	return 0, false
}

func rowInt32Safe(row map[string]any, key string) int32 {
	v, _ := rowInt32(row, key)
	return int32(v)
}

func rowInt64(row map[string]any, key string) int64 {
	v, _ := rowInt32(row, key)
	return v
}

func rowByte(row map[string]any, key string) byte {
	return byte(rowInt32Safe(row, key))
}

func rowFloat32(row map[string]any, key string) float32 {
	v, ok := row[key]
	if !ok || v == nil {
		return 0
	}
	switch val := v.(type) {
	case float32:
		return val
	case float64:
		return float32(val)
	}
	return 0
}

// --- binary write helpers ---

func appendInt32(buf *[]byte, v int32) {
	var b [4]byte
	binary.LittleEndian.PutUint32(b[:], uint32(v))
	*buf = append(*buf, b[:]...)
}

func appendInt64(buf *[]byte, v int64) {
	var b [8]byte
	binary.LittleEndian.PutUint64(b[:], uint64(v))
	*buf = append(*buf, b[:]...)
}

func appendFloat32(buf *[]byte, v float32) {
	appendInt32(buf, int32(math.Float32bits(v)))
}
