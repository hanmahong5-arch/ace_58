package main

import (
	"context"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"log/slog"
	"math"
	mrand "math/rand"
	"net"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
	"aion58/internal/ipc"
	"aion58/internal/session"
)

// gameConnDeps holds the shared (read-only after creation) dependencies
// injected into each game-port connection handler.
type gameConnDeps struct {
	store           session.TokenStoreIface
	events          *ipc.Client
	internalVersion int // opcode obfuscation version (4.8=207, 5.8=TBD)
}

// Game port raw opcodes — server→client (from BEY_4.8 ServerPacketsOpcodes).
// These are pre-obfuscation values; wire encoding adds INTERNAL_VERSION + XOR 0xDF.
const (
	gameOP_SM_KEY            = 72  // first packet: session key seed
	gameOP_SM_VERSION_CHECK  = 0   // response to CM_VERSION_CHECK
	gameOP_SM_CHARACTER_LIST = 200 // character list (empty = triggers creation UI)
)

// Game port client opcode slots — decoded index into handler array.
// 5.8 slots differ from 4.8 (4.8: L2AUTH=149, MAC=189).
const (
	gameSlot_CM_VERSION_CHECK      = 0
	gameSlot_CM_TIME_CHECK         = 38
	gameSlot_CM_L2AUTH_LOGIN_CHECK = 218
	gameSlot_CM_MAC_ADDRESS        = 194
	gameSlot_CM_CHARACTER_LIST     = 215
	gameSlot_CM_CREATE_CHARACTER   = 216 // Chinese 5.8 client (AionGermany uses 339/0x153)
	gameSlot_CM_ENTER_WORLD        = 187 // Chinese 5.8 client, 0B payload (4.8 was slot 8 + 4B objId)
)

// handleGameConn manages the game-port (:7777) connection lifecycle.
//
// Protocol flow (NCSoft/AL-Aion XOR-based):
//
//	SM_KEY (unencrypted, 4B enciphered key seed)
//	CM_VERSION_CHECK → SM_VERSION_CHECK
//	CM_L2AUTH_LOGIN_CHECK (playOk2+playOk1+accountId+loginOk)
//	CM_MAC_ADDRESS (informational, acknowledged)
//	SM_CHARACTER_LIST (empty = char creation screen)
func handleGameConn(conn net.Conn, deps gameConnDeps) {
	s := newSession(conn)
	var accountID int64
	defer func() {
		if s.account != "" {
			deps.events.PublishAsync(ipc.SubjectPlayerLeave, ipc.PlayerLeaveEvent{
				AccountID:    accountID,
				GatewaySeqID: s.id,
				Reason:       "disconnect",
			})
		}
		s.close()
	}()

	slog.Debug("gateway: game connection", "id", s.id, "addr", conn.RemoteAddr())

	// 1. Generate random base key and send SM_KEY (unencrypted).
	baseKey := mrand.Int31()
	gc := crypto.NewGameCrypt(baseKey)

	if err := sendGameSMKey(conn, baseKey, deps.internalVersion); err != nil {
		slog.Warn("gateway: sendGameSMKey failed", "id", s.id, "err", err)
		return
	}
	gc.Enable() // subsequent server packets will be encrypted
	slog.Info("gateway: sent game SM_KEY", "id", s.id)

	// 2. Read packets — expect CM_VERSION_CHECK, CM_L2AUTH_LOGIN_CHECK, CM_MAC_ADDRESS.
	//    Order may vary; process by decoded opcode slot.
	var authed bool
	_ = conn.SetReadDeadline(time.Now().Add(30 * time.Second))

	for i := 0; i < 10 && !authed; i++ {
		slot, payload, err := readGamePacket(conn, gc, deps.internalVersion)
		if err != nil {
			slog.Warn("gateway: read game packet", "id", s.id, "attempt", i, "err", err)
			return
		}
		slog.Info("gateway: game client packet",
			"id", s.id, "slot", slot, "payload_len", len(payload))

		switch slot {
		case gameSlot_CM_VERSION_CHECK:
			// Client sends its version — respond with SM_VERSION_CHECK.
			var clientVersion uint16
			if len(payload) >= 2 {
				clientVersion = binary.LittleEndian.Uint16(payload[0:2])
			}
			slog.Info("gateway: CM_VERSION_CHECK", "id", s.id, "client_version", clientVersion)

			if err := sendGameSMVersionCheck(conn, gc, deps.internalVersion); err != nil {
				slog.Warn("gateway: sendSMVersionCheck failed", "id", s.id, "err", err)
				return
			}

		case gameSlot_CM_L2AUTH_LOGIN_CHECK:
			// Session token from auth server: playOk2(4)+playOk1(4)+accountId(4)+loginOk(4)+unk(8)
			if len(payload) < 16 {
				slog.Warn("gateway: CM_L2AUTH payload too short", "id", s.id, "len", len(payload))
				return
			}
			playOk2 := binary.LittleEndian.Uint32(payload[0:4])
			playOk1 := binary.LittleEndian.Uint32(payload[4:8])
			acctID := binary.LittleEndian.Uint32(payload[8:12])
			loginOk := binary.LittleEndian.Uint32(payload[12:16])

			// Reconstruct the 16-byte token (same layout as stored in auth port).
			var token [16]byte
			binary.LittleEndian.PutUint32(token[0:4], acctID)
			binary.LittleEndian.PutUint32(token[4:8], loginOk)
			binary.LittleEndian.PutUint32(token[8:12], playOk1)
			binary.LittleEndian.PutUint32(token[12:16], playOk2)

			sessData, err := deps.store.VerifyRaw(s.ctx, token[:])
			if err != nil {
				slog.Warn("gateway: invalid session token", "id", s.id, "err", err)
				return
			}

			s.account = sessData.Account
			accountID = sessData.AccountID
			slog.Info("gateway: game session verified",
				"id", s.id, "account", sessData.Account, "account_id", sessData.AccountID,
				"playOk1", playOk1, "playOk2", playOk2)

			// Send SM_L2AUTH_LOGIN_CHECK (0xC7) — confirms auth OK to client.
			if err := sendGameSML2AuthResponse(conn, gc, deps.internalVersion, sessData.Account); err != nil {
				slog.Warn("gateway: sendSML2AuthResponse failed", "id", s.id, "err", err)
				return
			}
			authed = true

		case gameSlot_CM_MAC_ADDRESS:
			slog.Debug("gateway: CM_MAC_ADDRESS received", "id", s.id)

		case gameSlot_CM_TIME_CHECK:
			slog.Debug("gateway: CM_TIME_CHECK received", "id", s.id)

		default:
			slog.Debug("gateway: unknown game packet slot", "id", s.id, "slot", slot)
		}
	}

	if !authed {
		slog.Warn("gateway: auth timeout — no CM_L2AUTH received", "id", s.id)
		return
	}

	s.setState(stateInGame)

	// 3. Post-auth: wait for CM_CHARACTER_LIST and respond.
	//    Slot 215 = CM_CHARACTER_LIST in NCSoft 5.8 Chinese client.
	_ = conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	charListSent := false
	for i := 0; i < 10 && !charListSent; i++ {
		slot, _, err := readGamePacket(conn, gc, deps.internalVersion)
		if err != nil {
			slog.Warn("gateway: post-auth read failed", "id", s.id, "err", err)
			return
		}
		slog.Info("gateway: post-auth packet", "id", s.id, "slot", slot, "attempt", i)

		if slot == gameSlot_CM_MAC_ADDRESS || slot == gameSlot_CM_TIME_CHECK {
			continue
		}

		// CM_CHARACTER_LIST (slot 215 in 5.8) → 6-packet burst response
		slog.Info("gateway: CM_CHARACTER_LIST → sending 6-packet burst", "id", s.id, "slot", slot)
		if err := sendGameCharacterListBurst(conn, gc, deps.internalVersion, 0); err != nil {
			slog.Warn("gateway: sendGameCharacterListBurst failed", "id", s.id, "err", err)
			return
		}
		slog.Info("gateway: sent character list burst (ACCOUNT_PROPS×3 + UNK_14F + CHAR_LIST×2)", "id", s.id)
		charListSent = true
	}

	// 4. Notify World Engine.
	deps.events.PublishAsync(ipc.SubjectPlayerEnter, ipc.PlayerEnterEvent{
		AccountID:    accountID,
		Account:      s.account,
		GatewaySeqID: s.id,
		RemoteAddr:   conn.RemoteAddr().String(),
	})

	// 5. Packet relay loop — forward CM_* to NATS, receive SM_* from NATS.
	smSubject := fmt.Sprintf("%s.%d", ipc.SubjectWorldSM, s.id)
	unsubSM, subErr := ipc.Subscribe[ipc.PacketEvent](deps.events, smSubject,
		func(ev ipc.PacketEvent) {
			if err := sendGameServerPacket(conn, gc, deps.internalVersion, int(ev.Opcode), ev.Payload); err != nil {
				slog.Warn("gateway: SM forward failed", "id", s.id, "opcode", ev.Opcode, "err", err)
			}
		})
	if subErr != nil {
		slog.Warn("gateway: subscribe SM channel", "id", s.id, "err", subErr)
	} else {
		defer unsubSM()
	}

	runGameCMRelayLoop(s, conn, gc, deps)
}

// runGameCMRelayLoop reads XOR-encrypted CM_* packets from the client.
// Known packets are handled locally; unknown packets are forwarded to NATS.
func runGameCMRelayLoop(s *Session, conn net.Conn, gc *crypto.GameCrypt, deps gameConnDeps) {
	cmSubject := fmt.Sprintf("%s.%d", ipc.SubjectPlayerCM, s.id)
	const readTimeout = 60 * time.Second
	creationWindowOpened := false
	nextPlayerObjID := uint32(1001)

	for {
		_ = conn.SetReadDeadline(time.Now().Add(readTimeout))
		slot, payload, err := readGamePacket(conn, gc, deps.internalVersion)
		if err != nil {
			slog.Debug("gateway: game CM relay ended", "id", s.id, "err", err)
			return
		}

		slog.Info("gateway: game CM packet", "id", s.id, "slot", slot, "payload_len", len(payload))

		switch slot {
		case gameSlot_CM_CHARACTER_LIST:
			// 5.8 client 在角色选择界面发此包请求角色列表。当前 stub 总是回空账户
			// burst (count=0)。一旦 PG persist 接入，应改为查 aion_GetCharList 后
			// 把第一个 char_id 写进 s.setSelectedCharID() 供后续 CM_ENTER_WORLD 用。
			slog.Info("gateway: CM_CHARACTER_LIST re-request", "id", s.id)
			if err := sendGameCharacterListBurst(conn, gc, deps.internalVersion, 0); err != nil {
				slog.Warn("gateway: resend char list burst failed", "id", s.id, "err", err)
				return
			}

		case gameSlot_CM_CREATE_CHARACTER:
			if !creationWindowOpened {
				slog.Info("gateway: CM_CREATE_CHARACTER → OPEN_CREATION_WINDOW", "id", s.id)
				if err := sendCreateCharacterResponse(conn, gc, deps.internalVersion, 22); err != nil {
					slog.Warn("gateway: SM_CREATE_CHARACTER(OPEN) failed", "id", s.id, "err", err)
					return
				}
				creationWindowOpened = true
			} else {
				name, gender, race, class, appData := parseCreateCharInfo(payload)
				objID := nextPlayerObjID
				nextPlayerObjID++
				// 记录到 session — 后续 CM_ENTER_WORLD (0B) 用此 char_id 注入 Lua payload。
				s.setSelectedCharID(int32(objID))
				slog.Info("gateway: CM_CREATE_CHARACTER → creating stub",
					"id", s.id, "objID", objID, "name", name, "gender", gender,
					"race", race, "class", class, "appearance_len", len(appData))
				if err := sendCreateCharacterOK(conn, gc, deps.internalVersion, objID, name, gender, race, class, appData); err != nil {
					slog.Warn("gateway: SM_CREATE_CHARACTER(OK) failed", "id", s.id, "err", err)
					return
				}
				creationWindowOpened = false
			}

		case gameSlot_CM_TIME_CHECK, gameSlot_CM_MAC_ADDRESS:
			slog.Debug("gateway: game CM informational", "id", s.id, "slot", slot)

		case 3: // CM_QUIT — client "结束游戏" button
			slog.Info("gateway: CM_QUIT received, closing connection", "id", s.id)
			return

		default:
			// 翻译 5.8 slot → 4.8 Lua opcode（含 payload shape 修补，例如 CM_ENTER_WORLD
			// 注入 char_id）。映射存在时按 Lua opcode 转 NATS；不存在时按原 slot 转，
			// 留作 discovery dump 帮助识别未知包。
			luaOp, rewritten, mapped := translateClientCM58(slot, payload, s)
			if !mapped {
				dumpLen := len(payload)
				if dumpLen > 32 {
					dumpLen = 32
				}
				slog.Info("gateway: unmapped CM slot — discovery dump",
					"id", s.id, "slot", slot, "payload_len", len(payload),
					"hex_head", hex.EncodeToString(payload[:dumpLen]))
				deps.events.PublishAsync(cmSubject, ipc.PacketEvent{
					GatewaySeqID: s.id,
					Opcode:       uint16(slot),
					Payload:      payload,
				})
			} else {
				slog.Info("gateway: CM slot → Lua opcode forward",
					"id", s.id, "slot", slot, "lua_op", fmt.Sprintf("0x%02x", luaOp),
					"orig_len", len(payload), "rewritten_len", len(rewritten),
					"char_id", s.SelectedCharID())
				deps.events.PublishAsync(cmSubject, ipc.PacketEvent{
					GatewaySeqID: s.id,
					Opcode:       luaOp,
					Payload:      rewritten,
				})
			}
		}
	}
}

// --- Low-level game port packet I/O ---

// sendGameSMKey sends the first game port packet (SM_KEY) — UNENCRYPTED.
// Wire format: [2B size][2B obf_opcode][0x44][2B ~opcode][4B enciphered_key]
func sendGameSMKey(conn net.Conn, baseKey int32, version int) error {
	opEnc := crypto.EncodeServerOpcode(gameOP_SM_KEY, version)
	encKey := crypto.EncipherKey(baseKey, byte(version))

	// size = 2(size) + 2(opcode) + 1(static) + 2(~opcode) + 4(key) = 11
	var pkt [11]byte
	binary.LittleEndian.PutUint16(pkt[0:2], 11)
	binary.LittleEndian.PutUint16(pkt[2:4], opEnc)
	pkt[4] = crypto.ServerPacketCode
	binary.LittleEndian.PutUint16(pkt[5:7], ^opEnc)
	binary.LittleEndian.PutUint32(pkt[7:11], uint32(encKey))

	slog.Debug("gateway: game SM_KEY raw",
		"opcode_enc", fmt.Sprintf("0x%04x", opEnc),
		"enc_key", fmt.Sprintf("0x%08x", uint32(encKey)),
		"hex", fmt.Sprintf("%x", pkt[:]))

	_ = conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	_, err := conn.Write(pkt[:])
	return err
}

// sendGameServerPacket builds, obfuscates, encrypts, and sends a server→client game packet.
func sendGameServerPacket(conn net.Conn, gc *crypto.GameCrypt, version int, rawOpcode int, payload []byte) error {
	opEnc := crypto.EncodeServerOpcode(uint16(rawOpcode), version)

	// body = [2B opcode][1B 0x44][2B ~opcode][payload]
	bodyLen := 2 + 1 + 2 + len(payload)
	pkt := make([]byte, 2+bodyLen)
	binary.LittleEndian.PutUint16(pkt[0:2], uint16(len(pkt)))
	binary.LittleEndian.PutUint16(pkt[2:4], opEnc)
	pkt[4] = crypto.ServerPacketCode
	binary.LittleEndian.PutUint16(pkt[5:7], ^opEnc)
	copy(pkt[7:], payload)

	// XOR encrypt body (everything after 2B size header)
	gc.Encrypt(pkt[2:])

	_ = conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	_, err := conn.Write(pkt)
	return err
}

// readGamePacket reads one XOR-encrypted client packet and returns the decoded opcode slot + payload.
func readGamePacket(conn net.Conn, gc *crypto.GameCrypt, version int) (slot int, payload []byte, err error) {
	raw, err := aionproto.ReadPacketFromConn(conn)
	if err != nil {
		return 0, nil, fmt.Errorf("read game packet: %w", err)
	}

	body := raw[aionproto.HeaderSize:] // everything after 2B size
	if len(body) < 5 {
		return 0, nil, fmt.Errorf("game packet body too short: %d bytes", len(body))
	}

	slog.Debug("gateway: game packet pre-decrypt",
		"body_len", len(body),
		"hex", fmt.Sprintf("%x", body))

	// XOR decrypt body
	if !gc.Decrypt(body) {
		slog.Warn("gateway: game packet XOR decrypt validation failed",
			"body_hex", fmt.Sprintf("%x", body))
		return 0, nil, fmt.Errorf("game packet validation failed")
	}

	// Decode opcode: bytes[0:2] = encoded opcode
	encodedOp := binary.LittleEndian.Uint16(body[0:2])
	decodedOp := crypto.DecodeClientOpcode(encodedOp, version)
	// Skip header: [2B opcode][1B static=0x65][2B ~opcode] = 5 bytes
	return int(decodedOp), body[5:], nil
}

// sendGameSMVersionCheck sends SM_VERSION_CHECK with the 5.8 field layout.
// Source: AionGermany AL-Game-5.8 SM_VERSION_CHECK.java
func sendGameSMVersionCheck(conn net.Conn, gc *crypto.GameCrypt, version int) error {
	var buf [256]byte
	pos := 0
	wC := func(v byte) { buf[pos] = v; pos++ }
	wD := func(v uint32) { binary.LittleEndian.PutUint32(buf[pos:pos+4], v); pos += 4 }
	wH := func(v uint16) { binary.LittleEndian.PutUint16(buf[pos:pos+2], v); pos += 2 }

	now := uint32(time.Now().Unix())

	wC(0x00) // answerID = OK
	wC(0x01) // serverId = 1
	wD(180205) // startDate1
	wD(171201) // startDate2
	wD(0)      // spacing
	wD(180205) // startDate3
	wD(now)    // server epoch time
	wC(0x00)   // unk
	wC(0x05)   // country code (China)
	wC(0x80)   // serverMode flags (8 char slots * 0x10)
	wD(now)    // current epoch time
	{ tz := int32(-28800); binary.LittleEndian.PutUint32(buf[pos:pos+4], uint32(tz)); pos += 4 } // timezone UTC+8
	wD(40014200)              // unk constant
	// 5.8 new fields (not in 4.8)
	wD(0)     // unk
	wD(68536) // unk
	// 20 zero bytes
	for i := 0; i < 20; i++ {
		wC(0x00)
	}
	// 11x writeD(1000) — rate modifiers
	for i := 0; i < 11; i++ {
		wD(1000)
	}
	wH(25600) // unk
	wH(0)     // unk
	wC(0)     // unk
	wD(1000)  // unk
	wH(1)     // unk
	wC(0)     // unk
	// chat server IP (4B) + port (2B) — use loopback placeholder
	buf[pos] = 127; pos++
	buf[pos] = 0; pos++
	buf[pos] = 0; pos++
	buf[pos] = 1; pos++
	wH(10241) // chat port

	return sendGameServerPacket(conn, gc, version, gameOP_SM_VERSION_CHECK, buf[:pos])
}

// Game port server raw opcodes — 5.8 (from AionGermany ServerPacketsOpcodes.java).
const (
	gameOP_SM_L2AUTH_LOGIN_CHECK   = 0xC7
	gameOP_SM_MAY_LOGIN_INTO_GAME  = 0x89
	gameOP_SM_ACCOUNT_ACCESS_PROPS = 0xF0
	gameOP_SM_CREATE_CHARACTER     = 0xC9 // character creation response (5.8: 756B fixed)
	gameOP_SM_ENTER_WORLD_CHECK    = 0x0D // enter world ACK (4.8 opcode 13; 5.8 likely same since server opcodes mostly unchanged)
)

// l2authData is the 580-byte static blob from beyond-aion SM_L2AUTH_LOGIN_CHECK.java.
// Contains race tables only (no world maps — writeH(0) follows).
var l2authData []byte

func init() {
	var err error
	l2authData, err = hex.DecodeString(
		"000000000000000101010202020303030404040505050606060707070808080909090A0A0A0B0B0B0C0C0C0D0D0D0E0E0E0F0F0F1010101111111212121313131414141515151616161717171818181919191A1A1A1B1B1B1C1C1C1D1D1D1E1E1E1F1F1F2020202121212222222323232424242525252626262727272828282929292A2A2A2B2B2B2C2C2C2D2D2D2E2E2E2F2F2F3030303131313232323333333434343535353636363737373838383939393A3A3A3B3B3B3C3C3C000000000000000000000000000000423D3D0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101010202020303030404040505050606060707070808080909090A0A0A0B0B0B0C0C0C0D0D0D0E0E0E0F0F0F1010101111111212121313131414141515151616161717171818181919191A1A1A1B1B1B1C1C1C1D1D1D1E1E1E1F1F1F2020202121212222222323232424242525252626262727272828282929292A2A2A2B2B2B2C2C2C2D2D2D2E2E2E2F2F2F3030303131313232323333333434343535353636363737373838383939393A3A3A3B3B3B3C3C3C423D3D000000000000")
	if err != nil {
		panic("bad l2authData hex: " + err.Error())
	}
}

// sendGameSML2AuthResponse sends SM_L2AUTH_LOGIN_CHECK (0xC7) — confirms session auth.
// 5.8 format: writeD(result) + writeB(1812B data blob) + writeS(accountName).
func sendGameSML2AuthResponse(conn net.Conn, gc *crypto.GameCrypt, version int, account string) error {
	if account == "" {
		account = "player"
	}
	buf := make([]byte, 4+len(l2authData)+len(account)*2+2)
	pos := 0

	// writeD(0) — auth OK
	binary.LittleEndian.PutUint32(buf[pos:pos+4], 0)
	pos += 4
	// writeB(data) — 1812 bytes (race tables + world maps)
	copy(buf[pos:], l2authData)
	pos += len(l2authData)
	// writeS(accountName) — UTF-16LE null-terminated
	for _, r := range account {
		binary.LittleEndian.PutUint16(buf[pos:pos+2], uint16(r))
		pos += 2
	}
	buf[pos] = 0; pos++
	buf[pos] = 0; pos++

	slog.Debug("gateway: sending SM_L2AUTH_LOGIN_CHECK",
		"account", account, "payload_len", pos, "data_len", len(l2authData))
	return sendGameServerPacket(conn, gc, version, gameOP_SM_L2AUTH_LOGIN_CHECK, buf[:pos])
}


// sendGameCharacterListBurst sends the 5.8 character list response burst:
// SM_ACCOUNT_ACCESS_PROPERTIES ×3 + SM_UNK_14F + SM_CHARACTER_LIST type=0 + SM_CHARACTER_LIST type=2
func sendGameCharacterListBurst(conn net.Conn, gc *crypto.GameCrypt, version int, playOk2 uint32) error {
	// 1-3. SM_ACCOUNT_ACCESS_PROPERTIES (0xF0) ×3
	// 5.8: writeH×2 + writeD×4 + writeC + writeD×8 + 30B trailing = 83 bytes
	accProps := make([]byte, 83)
	binary.LittleEndian.PutUint32(accProps[33:37], 4) // accountType=4 (Veteran, full 8 char slots)
	for i := 0; i < 3; i++ {
		if err := sendGameServerPacket(conn, gc, version, gameOP_SM_ACCOUNT_ACCESS_PROPS, accProps); err != nil {
			return fmt.Errorf("SM_ACCOUNT_ACCESS_PROPERTIES[%d]: %w", i, err)
		}
	}

	// 4. SM_UNK_14F (0x14F) — empty packet
	if err := sendGameServerPacket(conn, gc, version, 0x14F, nil); err != nil {
		return fmt.Errorf("SM_UNK_14F: %w", err)
	}

	// 5. SM_CHARACTER_LIST type=0 (empty signal): writeC(0) + writeD(playOk2) + writeC(0)
	charList0 := make([]byte, 6)
	charList0[0] = 0x00 // listType = 0
	binary.LittleEndian.PutUint32(charList0[1:5], playOk2)
	charList0[5] = 0x00
	if err := sendGameServerPacket(conn, gc, version, gameOP_SM_CHARACTER_LIST, charList0); err != nil {
		return fmt.Errorf("SM_CHARACTER_LIST type=0: %w", err)
	}

	// 6. SM_CHARACTER_LIST type=2 (char data, 0 chars): writeC(2) + writeD(playOk2) + writeC(0)
	charList2 := make([]byte, 6)
	charList2[0] = 0x02 // listType = 2
	binary.LittleEndian.PutUint32(charList2[1:5], playOk2)
	charList2[5] = 0x00 // 0 characters
	if err := sendGameServerPacket(conn, gc, version, gameOP_SM_CHARACTER_LIST, charList2); err != nil {
		return fmt.Errorf("SM_CHARACTER_LIST type=2: %w", err)
	}

	return nil
}

// sendCreateCharacterResponse sends SM_CREATE_CHARACTER (0xC9) with error/window code.
// 5.8: writeD(code) + 752 zero-padding = 756 bytes total.
func sendCreateCharacterResponse(conn net.Conn, gc *crypto.GameCrypt, version int, code uint32) error {
	buf := make([]byte, 756)
	binary.LittleEndian.PutUint32(buf[0:4], code)
	return sendGameServerPacket(conn, gc, version, gameOP_SM_CREATE_CHARACTER, buf)
}

// parseCreateCharInfo extracts name, gender, race, class, and raw appearance bytes
// from CM_CREATE_CHARACTER payload.
// CM format: readD(accountId) + readS(accountName) + readS(charName)+pad(52B) + readD×3 + appearance + type
// AION readS = null-terminated UTF-16LE (NOT length-prefixed).
func parseCreateCharInfo(payload []byte) (name string, gender, race, class uint32, appearance []byte) {
	if len(payload) < 20 {
		return "Hero", 0, 0, 0, nil
	}
	pos := 4 // skip accountId

	// skip accountName: null-terminated UTF-16LE
	for pos+1 < len(payload) {
		ch := binary.LittleEndian.Uint16(payload[pos : pos+2])
		pos += 2
		if ch == 0 {
			break
		}
	}

	// read charName: null-terminated UTF-16LE, total field = 52 bytes from here
	charNameStart := pos
	var runes []rune
	for pos+1 < len(payload) {
		ch := binary.LittleEndian.Uint16(payload[pos : pos+2])
		pos += 2
		if ch == 0 {
			break
		}
		if len(runes) < 25 {
			runes = append(runes, rune(ch))
		}
	}
	if len(runes) > 0 {
		name = string(runes)
	} else {
		name = "Hero"
	}
	pos = charNameStart + 52

	// read gender, race, class
	if pos+12 > len(payload) {
		return name, 0, 0, 0, nil
	}
	gender = binary.LittleEndian.Uint32(payload[pos : pos+4])
	pos += 4
	race = binary.LittleEndian.Uint32(payload[pos : pos+4])
	pos += 4
	class = binary.LittleEndian.Uint32(payload[pos : pos+4])
	pos += 4

	// appearance data: voice through height (everything after class, minus last 2 bytes for type+extra)
	appEnd := len(payload) - 2
	if appEnd > pos {
		appearance = make([]byte, appEnd-pos)
		copy(appearance, payload[pos:appEnd])
	}
	return
}

// sendCreateCharacterOK sends SM_CREATE_CHARACTER with RESPONSE_OK + writePlayerInfo.
// Copies appearance data (voice→height) from the CM payload so the character looks as designed.
// 5.8 total = 756 bytes.
func sendCreateCharacterOK(conn net.Conn, gc *crypto.GameCrypt, version int, objID uint32, name string, gender, race, class uint32, appData []byte) error {
	buf := make([]byte, 756)
	pos := 0
	wD := func(v uint32) { binary.LittleEndian.PutUint32(buf[pos:pos+4], v); pos += 4 }
	wH := func(v uint16) { binary.LittleEndian.PutUint16(buf[pos:pos+2], v); pos += 2 }
	wF := func(v float32) { binary.LittleEndian.PutUint32(buf[pos:pos+4], math.Float32bits(v)); pos += 4 }

	// responseCode = 0 (OK)
	wD(0)
	// --- writePlayerInfo ---
	wD(objID)
	// writeS(name, 52): null-terminated UTF-16LE padded to 52B
	nameStart := pos
	for _, r := range name {
		if pos-nameStart >= 50 {
			break
		}
		binary.LittleEndian.PutUint16(buf[pos:pos+2], uint16(r))
		pos += 2
	}
	pos = nameStart + 52

	wD(gender)
	wD(race)
	wD(class)

	// Copy appearance bytes (voice+RGB+face details+height) from CM payload
	if len(appData) > 0 {
		copy(buf[pos:pos+len(appData)], appData)
		pos += len(appData)
	}

	// SM-only fields after appearance: genderCode, map, position, level, etc.
	if gender == 0 {
		wD(100000)
	} else {
		wD(100001)
	}
	if race == 0 {
		wD(210010000) // Poeta (Elyos start)
	} else {
		wD(220010000) // Ishalgen (Asmodian start)
	}
	wF(576.0); wF(253.0); wF(1683.0) // spawn x,y,z
	wD(0)   // heading
	wH(1)   // level
	wH(0)   // reserved
	wD(0)   // titleId
	wD(0)   // legionId
	pos += 82 // legionName (82 zeros)
	wH(0)   // legionMemberFlag
	wD(uint32(time.Now().Unix()))
	pos += 208 // equipment (no items)
	// remaining: deletionTime, helmet, mail, kinah, ban — all zeros

	slog.Info("gateway: SM_CREATE_CHARACTER OK built",
		"name", name, "appearance_len", len(appData), "pos", pos)
	return sendGameServerPacket(conn, gc, version, gameOP_SM_CREATE_CHARACTER, buf)
}

// verifyAccountAsync wraps a synchronous DB call so it respects context cancellation.
func verifyAccountAsync(ctx context.Context, fn func() (int64, error)) (int64, error) {
	type result struct {
		id  int64
		err error
	}
	ch := make(chan result, 1)
	go func() {
		id, err := fn()
		ch <- result{id, err}
	}()
	select {
	case <-ctx.Done():
		return 0, ctx.Err()
	case r := <-ch:
		return r.id, r.err
	}
}
