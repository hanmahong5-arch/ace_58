package main

import (
	"context"
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
	xorEnc   *crypto.XORCipher  // XOR encoder (server → client)
	xorDec   *crypto.XORCipher  // XOR decoder (client → server)

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
		id:     atomic.AddUint64(&sessionCounter, 1),
		conn:   conn,
		state:  int32(stateNew),
		xorEnc: crypto.NewXORCipher(),
		xorDec: crypto.NewXORCipher(),
		ctx:    ctx,
		cancel: cancel,
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
