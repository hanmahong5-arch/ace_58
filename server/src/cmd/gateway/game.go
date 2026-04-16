package main

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
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
	store  session.TokenStoreIface // session token verification
	events *ipc.Client             // NATS event bus (may be nil-equivalent NilClient)
}

// handleGameConn manages the game-port (:7777) connection lifecycle.
//
// Protocol flow:
//
//	[server → client]  SM_SESSION_KEY  — 16-byte per-session BF key
//	[client → server]  CM_SESSION_CONFIRM — 16-byte token (from SM_PLAY_OK)
//	Gateway verifies token → Redis one-time lookup
//	Gateway publishes player.enter → NATS → World Engine
//	Packet relay loop: CM_* → NATS → World; World → NATS → SM_* → client
func handleGameConn(conn net.Conn, deps gameConnDeps) {
	s := newSession(conn)
	// accountID is set after token verification; captured by the leave event defer.
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

	// 1. Generate a unique per-session BF key for game-port traffic.
	//    This key is different from the static auth key — each connection gets
	//    its own key, preventing replay and key reuse across sessions.
	var gameKey [16]byte
	if _, err := rand.Read(gameKey[:]); err != nil {
		slog.Error("gateway: game key generation failed", "id", s.id, "err", err)
		return
	}

	// 2. Send SM_SESSION_KEY (unencrypted — BF not yet active on this port).
	if err := sendSMSessionKey(s, gameKey[:]); err != nil {
		slog.Warn("gateway: sendSMSessionKey failed", "id", s.id, "err", err)
		return
	}
	s.setState(stateKeysSent)

	// Enable BF-LE with the session-specific key.
	gameBF, err := crypto.NewBlowfishLE(gameKey[:])
	if err != nil {
		slog.Error("gateway: game BF init", "id", s.id, "err", err)
		return
	}
	s.bfCipher = gameBF

	// 3. Read CM_SESSION_CONFIRM.
	pkt, err := s.readPacket()
	if err != nil {
		slog.Warn("gateway: read CM_SESSION_CONFIRM", "id", s.id, "err", err)
		return
	}
	if pkt.Opcode() != aionproto.CM_SESSION_CONFIRM {
		slog.Warn("gateway: expected CM_SESSION_CONFIRM",
			"id", s.id, "opcode", pkt.Opcode())
		return
	}

	rawToken, err := pkt.ReadBytes(16)
	if err != nil {
		slog.Warn("gateway: read session token bytes", "id", s.id, "err", err)
		return
	}

	// 4. Verify token — atomic Redis GET + DEL (one-time use).
	sessData, err := deps.store.VerifyRaw(s.ctx, rawToken)
	if err != nil {
		slog.Warn("gateway: invalid or expired session token",
			"id", s.id, "err", err)
		_ = sendGameError(s, 0x03)
		return
	}

	s.account = sessData.Account
	accountID = sessData.AccountID // populate defer-captured variable
	s.setState(stateInGame)
	slog.Info("gateway: game session established",
		"id", s.id,
		"account", sessData.Account,
		"account_id", sessData.AccountID)

	// 5. Notify World Engine.
	if err := deps.events.Publish(ipc.SubjectPlayerEnter, ipc.PlayerEnterEvent{
		AccountID:    sessData.AccountID,
		Account:      sessData.Account,
		GatewaySeqID: s.id,
		RemoteAddr:   conn.RemoteAddr().String(),
	}); err != nil {
		slog.Warn("gateway: publish player.enter", "id", s.id, "err", err)
		// Non-fatal: continue. Character list will come when World ACKs.
	}

	// 6. Subscribe to SM_* packets that World sends back for this session.
	smSubject := fmt.Sprintf("%s.%d", ipc.SubjectWorldSM, s.id)
	unsubSM, subErr := ipc.Subscribe[ipc.PacketEvent](deps.events, smSubject,
		func(ev ipc.PacketEvent) {
			forwardSMPacket(s, ev)
		})
	if subErr != nil {
		slog.Warn("gateway: subscribe SM channel", "id", s.id, "err", subErr)
		// Continue — gameplay won't work but connection stays alive.
	} else {
		defer unsubSM()
	}

	// 7. Packet relay loop.
	runCMRelayLoop(s, deps.events)
}

// runCMRelayLoop reads CM_* packets from the client, publishes them to NATS.
// Exits when the client disconnects or the read times out.
func runCMRelayLoop(s *Session, events *ipc.Client) {
	cmSubject := fmt.Sprintf("player.cm.%d", s.id)
	const readTimeout = 60 * time.Second

	for {
		_ = s.conn.SetReadDeadline(time.Now().Add(readTimeout))

		pkt, err := s.readPacket()
		if err != nil {
			slog.Debug("gateway: CM relay loop ended", "id", s.id, "err", err)
			return
		}

		payload, _ := pkt.ReadBytes(pkt.Remaining())
		events.PublishAsync(cmSubject, ipc.PacketEvent{
			GatewaySeqID: s.id,
			Opcode:       pkt.Opcode(),
			Payload:      payload,
		})
	}
}

// forwardSMPacket receives an SM_* event from NATS and sends it to the client.
func forwardSMPacket(s *Session, ev ipc.PacketEvent) {
	pkt := aionproto.NewPacket(ev.Opcode)
	pkt.WriteBytes(ev.Payload)
	if err := s.sendPacket(pkt); err != nil {
		slog.Warn("gateway: SM forward failed",
			"id", s.id, "opcode", ev.Opcode, "err", err)
	}
}

// sendSMSessionKey sends the SM_SESSION_KEY packet (first packet on game port).
//
//	[2B]  opcode SM_SESSION_KEY (0x1A)
//	[16B] random per-session BF key
//	[8B]  padding zeros
func sendSMSessionKey(s *Session, gameKey []byte) error {
	if len(gameKey) < 16 {
		return fmt.Errorf("sendSMSessionKey: key too short (%d bytes)", len(gameKey))
	}
	pkt := aionproto.NewPacket(aionproto.SM_SESSION_KEY)
	pkt.WriteBytes(gameKey[:16])
	pkt.WriteUint64(0) // 8-byte padding
	slog.Debug("gateway: sending SM_SESSION_KEY", "session", s.id)
	return s.sendPacket(pkt)
}

// sendGameError sends a lightweight error packet to signal session failure.
func sendGameError(s *Session, code byte) error {
	pkt := aionproto.NewPacket(0x0F) // reserved error opcode
	pkt.WriteByte(code)
	return s.sendPacket(pkt)
}

// verifyAccountAsync wraps a synchronous DB call so it respects context cancellation.
// Prevents the gateway from blocking forever on a slow database query.
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
