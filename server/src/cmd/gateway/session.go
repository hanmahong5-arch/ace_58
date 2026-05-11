package main

import (
	"context"
	"encoding/binary"
	"fmt"
	"log/slog"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
)

// sessionState tracks the authentication stage of a connection.
type sessionState int32

const (
	stateNew      sessionState = iota // TCP connected, SM_KEY not yet sent
	stateKeysSent                     // SM_KEY sent, awaiting CM_AUTH_LOGIN
	stateAuthed                       // credentials verified, server list sent
	stateInGame                       // CM_PLAY accepted, in world
)

// writeTimeout is the maximum time allowed for a single write to the client.
const writeTimeout = 5 * time.Second

// Session represents one client connection to the gateway.
// All public methods are safe for concurrent use.
type Session struct {
	id      uint64   // monotonically increasing session ID
	conn    net.Conn // underlying TCP connection
	state   int32    // sessionState, accessed via atomic ops
	account string   // populated after auth; empty before

	// Crypto state — one cipher instance per direction.
	bfCipher *crypto.BlowfishLE // BF-LE cipher (shared enc/dec key)
	xorEnc   *crypto.XORCipher  // XOR encoder (server → client, game port)
	xorDec   *crypto.XORCipher  // XOR decoder (client → server, game port)

	// CryptEngine state — tracks first-packet XOR pass for auth port.
	firstClientPkt bool // true until first client packet decrypted

	// 5.8 CM_ENTER_WORLD payload 是 0B（不带 char_id）；4.8 Lua handler 期望 4B
	// char_id。Gateway 在 CM_CHARACTER_LIST / CM_CREATE_CHARACTER 阶段记录"当前
	// 选定的角色"，在 ENTER_WORLD 转发到 Lua 前注入到 payload 头部，使 Lua 业务
	// 层无须感知 wire format 版本差异。原子访问。
	selectedCharID int32

	// Write serialisation — prevents interleaved packet bytes.
	writeMu sync.Mutex

	// closeOnce ensures cleanup runs exactly once, regardless of concurrency.
	closeOnce sync.Once

	// Context used for DB / NATS calls; cancelled when session closes.
	ctx    context.Context
	cancel context.CancelFunc
}

var sessionCounter uint64 // global monotonic counter

// newSession creates a Session for a freshly accepted TCP connection.
func newSession(conn net.Conn) *Session {
	ctx, cancel := context.WithCancel(context.Background())
	return &Session{
		id:             atomic.AddUint64(&sessionCounter, 1),
		conn:           conn,
		state:          int32(stateNew),
		xorEnc:         crypto.NewXORCipher(),
		xorDec:         crypto.NewXORCipher(),
		firstClientPkt: true,
		ctx:            ctx,
		cancel:         cancel,
	}
}

// close terminates the session: cancels context, closes TCP connection.
// Idempotent — safe to call multiple times from different goroutines.
func (s *Session) close() {
	s.closeOnce.Do(func() {
		s.cancel()
		_ = s.conn.Close()
		slog.Debug("session: closed", "id", s.id, "addr", s.conn.RemoteAddr())
	})
}

// setState atomically updates the session state.
func (s *Session) setState(next sessionState) {
	atomic.StoreInt32(&s.state, int32(next))
}

// getState returns the current session state.
func (s *Session) getState() sessionState {
	return sessionState(atomic.LoadInt32(&s.state))
}

// SelectedCharID 返回 gateway 当前已"锁定"的 char_id（线程安全）。0 表示未选定。
func (s *Session) SelectedCharID() int32 {
	return atomic.LoadInt32(&s.selectedCharID)
}

// setSelectedCharID 在 CM_CHARACTER_LIST / CM_CREATE_CHARACTER 阶段调用，记录
// 后续 CM_ENTER_WORLD 应该带的 char_id。
func (s *Session) setSelectedCharID(charID int32) {
	atomic.StoreInt32(&s.selectedCharID, charID)
}

// sendPacket encrypts and writes a packet to the client.
// Encryption is applied only after SM_KEY has been sent (stateKeysSent+).
//
// Thread-safe: acquires writeMu before writing to the connection.
func (s *Session) sendPacket(pkt *aionproto.Packet) error {
	raw := pkt.Bytes()
	currentState := s.getState()

	s.writeMu.Lock()
	defer s.writeMu.Unlock()

	// Apply BF-LE encryption after the initial key exchange.
	if s.bfCipher != nil && currentState >= stateKeysSent {
		s.bfCipher.EncryptPacket(raw)
	}

	// XOR encode the payload (bytes after the 2-byte length header).
	if currentState >= stateKeysSent && len(raw) > aionproto.HeaderSize {
		s.xorEnc.Encode(raw[aionproto.HeaderSize:])
	}

	_ = s.conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	_, err := s.conn.Write(raw)
	return err
}

// readPacket reads one AION packet from the client, BF-decrypts and XOR-decodes it.
func (s *Session) readPacket() (*aionproto.Packet, error) {
	raw, err := aionproto.ReadPacketFromConn(s.conn)
	if err != nil {
		return nil, err
	}

	currentState := s.getState()

	// Decrypt BF-LE then XOR (reverse of encrypt order).
	if s.bfCipher != nil && currentState >= stateKeysSent {
		s.bfCipher.DecryptPacket(raw)
	}
	if currentState >= stateKeysSent && len(raw) > aionproto.HeaderSize {
		s.xorDec.Decode(raw[aionproto.HeaderSize:])
	}

	return aionproto.FromBytes(raw)
}

// readAuthPacket reads a BF-encrypted auth-port packet (1B opcode).
// NCSoft 5.8 client encrypts with BF only (no XOR pass, no checksum).
func (s *Session) readAuthPacket() (opcode byte, payload []byte, err error) {
	raw, err := aionproto.ReadPacketFromConn(s.conn)
	if err != nil {
		return 0, nil, fmt.Errorf("read auth packet: %w", err)
	}

	body := raw[aionproto.HeaderSize:]
	bodyLen := len(body)

	// BF-LE decrypt all blocks
	if s.bfCipher != nil && s.getState() >= stateKeysSent {
		for i := 0; i+8 <= bodyLen; i += 8 {
			s.bfCipher.DecryptBlock(body[i:i+8], body[i:i+8])
		}
	}

	slog.Debug("auth: decrypted body",
		"session", s.id,
		"len", bodyLen,
		"hex", fmt.Sprintf("%x", body))

	if bodyLen < 1 {
		return 0, nil, fmt.Errorf("auth packet body empty")
	}

	return body[0], body[1:], nil
}

// sendAuthPacket builds and sends a CryptEngine-encrypted auth-port packet (1B opcode).
// Matches AL-Aion CryptEngine.encrypt() updatedKey path:
// content + 4B checksum + padding(8-aligned, always >=1) + appendChecksum + BF encrypt.
func (s *Session) sendAuthPacket(opcode byte, payload []byte) error {
	contentLen := 1 + len(payload)
	bodyLen := contentLen + 4                // +4 checksum (CryptEngine always adds this)
	bodyLen += 8 - bodyLen%8                 // alignment (always adds 1-8 bytes)
	raw := make([]byte, aionproto.HeaderSize+bodyLen)
	binary.LittleEndian.PutUint16(raw[0:2], uint16(len(raw)))
	raw[aionproto.HeaderSize] = opcode
	copy(raw[aionproto.HeaderSize+1:], payload)

	body := raw[aionproto.HeaderSize:]
	appendChecksum(body, 0, bodyLen)

	// BF-LE encrypt body
	if s.bfCipher != nil && s.getState() >= stateKeysSent {
		for i := 0; i+8 <= bodyLen; i += 8 {
			s.bfCipher.EncryptBlock(body[i:i+8], body[i:i+8])
		}
	}

	slog.Debug("auth: sending packet",
		"session", s.id,
		"opcode", fmt.Sprintf("0x%02x", opcode),
		"body_len", bodyLen,
		"raw_hex", fmt.Sprintf("%x", raw))

	s.writeMu.Lock()
	defer s.writeMu.Unlock()
	_ = s.conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	_, err := s.conn.Write(raw)
	return err
}
