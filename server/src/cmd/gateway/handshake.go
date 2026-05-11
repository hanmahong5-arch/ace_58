package main

import (
	"encoding/binary"
	"fmt"
	"log/slog"
	mrand "math/rand"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
)

// decXORPass reverses encXORPass by reading the stored accumulator
// from data[stop:stop+4] and working backwards.
func decXORPass(data []byte, offset, length int) {
	if length < 12 {
		return
	}
	stop := length - 8
	startPos := 4 + offset
	// Find stored ecx position (mirrors encXORPass loop exit)
	ecxPos := startPos
	for ecxPos+4 <= stop {
		ecxPos += 4
	}
	ecx := binary.LittleEndian.Uint32(data[ecxPos : ecxPos+4])
	for p := ecxPos - 4; p >= startPos; p -= 4 {
		edx := binary.LittleEndian.Uint32(data[p : p+4])
		edx ^= ecx
		ecx -= edx
		binary.LittleEndian.PutUint32(data[p:p+4], edx)
	}
}

// appendChecksum writes an XOR checksum at data[offset+length-4 : offset+length].
// Matches CryptEngine.appendChecksum() from AL-Aion.
func appendChecksum(data []byte, offset, length int) {
	if length < 8 {
		return
	}
	var chksum uint32
	count := offset + length - 4
	for i := offset; i < count; i += 4 {
		chksum ^= binary.LittleEndian.Uint32(data[i : i+4])
	}
	binary.LittleEndian.PutUint32(data[count:count+4], chksum)
}

// encXORPass implements NCSoft CryptEngine's first-packet XOR scramble.
// Ported from AL-Aion CryptEngine.java encXORPass().
func encXORPass(data []byte, offset, length int, key uint32) {
	stop := length - 8
	pos := 4 + offset
	ecx := key

	for pos < stop {
		edx := binary.LittleEndian.Uint32(data[pos : pos+4])
		ecx += edx
		edx ^= ecx
		binary.LittleEndian.PutUint32(data[pos:pos+4], edx)
		pos += 4
	}
	// Store final accumulator
	binary.LittleEndian.PutUint32(data[pos:pos+4], ecx)
}

// buildAuthPacket builds a raw auth-port packet: [2B size LE][1B opcode][payload].
// NCSoft LoginServer uses 1-byte opcode, not 2-byte like the game port.
func buildAuthPacket(opcode byte, payload []byte) []byte {
	size := 2 + 1 + len(payload) // size field + opcode + payload
	buf := make([]byte, size)
	binary.LittleEndian.PutUint16(buf[0:2], uint16(size))
	buf[2] = opcode
	copy(buf[3:], payload)
	return buf
}

// sendSMKey sends SM_KEY with NCSoft SM_INIT payload layout + RSA scramble.
// Uses 1B opcode (auth-port format). SM_KEY is always unencrypted (state=stateNew),
// so we write raw bytes directly to conn, bypassing sendPacket/sendAuthPacket.
func (s *Session) sendSMKey(rsaScrambled []byte, bfStaticKey []byte, country int) error {
	if len(rsaScrambled) != crypto.CredentialBlockSize {
		return fmt.Errorf("sendSMKey: RSA modulus must be %d bytes", crypto.CredentialBlockSize)
	}
	if len(bfStaticKey) != 16 {
		return fmt.Errorf("sendSMKey: BF key must be 16 bytes")
	}

	// Build SM_INIT payload: sessionId(4) + revision(4) + RSA(128) + pad(16) +
	// BF(16) + pad(7) + testServerId(1) + testServerIP(4) + testServerPort(2) +
	// flag(1) + unk(4, 0x3FCE09ED) + unk(4, zeros) = 187 bytes
	payload := make([]byte, 0, 187)
	b4 := make([]byte, 4)
	b2 := make([]byte, 2)

	binary.LittleEndian.PutUint32(b4, uint32(s.id))
	payload = append(payload, b4...)                  // session_id (4)
	binary.LittleEndian.PutUint32(b4, 0x0000c621)
	payload = append(payload, b4...)                  // protocol revision (4)
	payload = append(payload, rsaScrambled...)         // RSA modulus, scrambled (128)
	payload = append(payload, make([]byte, 16)...)     // spacer (16)
	payload = append(payload, bfStaticKey...)           // BF key (16)
	payload = append(payload, make([]byte, 7)...)      // spacer (7)
	payload = append(payload, 0)                       // test server id (1)
	payload = append(payload, 0, 0, 0, 0)              // test server ip (4)
	binary.LittleEndian.PutUint16(b2, 0)
	payload = append(payload, b2...)                   // test server port (2)
	payload = append(payload, 0)                       // flag (1)
	binary.LittleEndian.PutUint32(b4, 0x3FCE09ED)
	payload = append(payload, b4...)                   // unk constant (4)
	binary.LittleEndian.PutUint32(b4, 0)
	payload = append(payload, b4...)                   // unk zeros (4)

	// Build raw body: [1B opcode][payload]
	body := append([]byte{byte(aionproto.SM_KEY)}, payload...)

	// NCSoft CryptEngine first-packet encryption:
	// 1. Add 4 bytes checksum space
	// 2. Add 4 bytes XOR seed space
	// 3. Align to 8-byte boundary
	// 4. encXORPass with random seed
	// 5. BF-LE encrypt with static key
	bodyLen := len(body)
	bodyLen += 4 // checksum
	bodyLen += 4 // XOR seed
	if bodyLen%8 != 0 {
		bodyLen += 8 - bodyLen%8
	}
	// Expand body to padded length (zeros fill checksum+seed+padding)
	padded := make([]byte, bodyLen)
	copy(padded, body)

	// encXORPass: XOR from offset 4, store final ecx at end
	seed := mrand.Uint32()
	encXORPass(padded, 0, bodyLen, seed)

	// BF-LE encrypt with static key
	initBF, bfErr := crypto.NewBlowfishLE(bfStaticKey)
	if bfErr != nil {
		return fmt.Errorf("sendSMKey: init BF: %w", bfErr)
	}
	for i := 0; i+8 <= bodyLen; i += 8 {
		initBF.EncryptBlock(padded[i:i+8], padded[i:i+8])
	}

	// Prepend 2B length header
	raw := make([]byte, 2+bodyLen)
	binary.LittleEndian.PutUint16(raw[0:2], uint16(len(raw)))
	copy(raw[2:], padded)

	slog.Debug("gateway: sending SM_KEY", "session", s.id, "raw_len", len(raw))

	s.writeMu.Lock()
	defer s.writeMu.Unlock()
	_ = s.conn.SetWriteDeadline(time.Now().Add(writeTimeout))
	_, err := s.conn.Write(raw)
	return err
}

// handleCMAuthLoginRaw decrypts credentials from raw 1B-opcode auth payload.
func handleCMAuthLoginRaw(payload []byte, rsaKP *crypto.RSAKeyPair) (account, password string, err error) {
	if len(payload) < crypto.CredentialBlockSize {
		return "", "", fmt.Errorf("CM_AUTH_LOGIN payload too short: %d", len(payload))
	}
	credBlock := payload[:crypto.CredentialBlockSize]
	plain, err := rsaKP.DecryptCredentials(credBlock)
	if err != nil {
		return "", "", fmt.Errorf("RSA decrypt: %w", err)
	}
	slog.Debug("gateway: RSA decrypted credential block",
		"hex", fmt.Sprintf("%x", plain),
		"first_20", fmt.Sprintf("%x", plain[:20]))
	return crypto.ParseCredentials(plain)
}

// sendSMAuthGG sends SM_AUTH_GG (AC_GAMEGUARD) echoing the client's session ID.
// Matches AL-Aion SM_AUTH_GG.java writeImpl().
func (s *Session) sendSMAuthGG(sessionID uint32) error {
	buf := make([]byte, 0, 40)
	b4 := make([]byte, 4)

	binary.LittleEndian.PutUint32(b4, sessionID)
	buf = append(buf, b4...) // sessionId (4)
	binary.LittleEndian.PutUint32(b4, 0)
	buf = append(buf, b4...) // zeros (4)
	buf = append(buf, b4...) // zeros (4)
	buf = append(buf, b4...) // zeros (4)
	buf = append(buf, b4...) // zeros (4)

	binary.LittleEndian.PutUint32(b4, 0xCD5000)
	buf = append(buf, b4...) // xor + opcode marker (4)
	binary.LittleEndian.PutUint32(b4, 0)
	buf = append(buf, b4...) // zeros (4)
	binary.LittleEndian.PutUint32(b4, 0x0b<<24)
	buf = append(buf, b4...) // opcode marker (4)
	binary.LittleEndian.PutUint32(b4, sessionID^0xCD5000)
	buf = append(buf, b4...)    // sessionId ^ 0xCD5000 (4)
	buf = append(buf, 0, 0, 0) // padding (3)

	slog.Debug("gateway: sending SM_AUTH_GG", "session", s.id, "sessionId", sessionID)
	return s.sendAuthPacket(byte(aionproto.SM_AUTH_GG), buf)
}

// sendSMLoginOKAuth sends SM_LOGIN_OK (AC_LOGIN_OK, 0x03) with session key.
// Matches AL-Aion SM_LOGIN_OK.java. The server list is sent separately via SM_SERVER_LIST.
func (s *Session) sendSMLoginOKAuth(accountID int32, loginOk int32) error {
	buf := make([]byte, 0, 67)
	b4 := make([]byte, 4)

	binary.LittleEndian.PutUint32(b4, uint32(accountID))
	buf = append(buf, b4...) // accountId (4)
	binary.LittleEndian.PutUint32(b4, uint32(loginOk))
	buf = append(buf, b4...) // loginOk (4)
	binary.LittleEndian.PutUint32(b4, 0)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	binary.LittleEndian.PutUint32(b4, 0x000003ea)
	buf = append(buf, b4...) // 0x3ea (4)
	binary.LittleEndian.PutUint32(b4, 0)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, b4...) // 0 (4)
	buf = append(buf, make([]byte, 0x13)...) // padding (19)

	slog.Debug("gateway: sending SM_LOGIN_OK", "session", s.id, "account_id", accountID)
	return s.sendAuthPacket(byte(aionproto.SM_LOGIN_OK), buf)
}

// sendSMServerList sends SM_SERVER_LIST (AC_SEND_SERVER_LIST, 0x04).
// Matches AL-Aion SM_SERVER_LIST.java.
func (s *Session) sendSMServerList(servers []ServerEntry) error {
	buf := make([]byte, 0, 128)

	buf = append(buf, byte(len(servers))) // server count (1)
	buf = append(buf, 1)                  // last server ID (1)

	for _, srv := range servers {
		buf = append(buf, byte(srv.ID)) // server id (1)

		// IP as 4 raw bytes (network order)
		var a, b, c, d byte
		fmt.Sscanf(srv.Host, "%d.%d.%d.%d", &a, &b, &c, &d)
		buf = append(buf, a, b, c, d) // ip (4)

		b2 := make([]byte, 2)
		binary.LittleEndian.PutUint16(b2, uint16(srv.Port))
		buf = append(buf, b2...)   // port (2)
		buf = append(buf, 0, 0)    // unk (2)
		buf = append(buf, 0)       // age limit (1)
		buf = append(buf, 0)       // pvp (1)
		binary.LittleEndian.PutUint16(b2, uint16(srv.Online))
		buf = append(buf, b2...)   // current players (2)
		binary.LittleEndian.PutUint16(b2, uint16(srv.MaxPlayers))
		buf = append(buf, b2...)   // max players (2)
		buf = append(buf, 1)       // is_online (1)
		buf = append(buf, 1)       // server_type 1=normal (1)
		buf = append(buf, 0)       // hide (1)
		buf = append(buf, 0, 0)    // unk (2)
		buf = append(buf, 0)       // brackets (1)
	}

	b2 := make([]byte, 2)
	binary.LittleEndian.PutUint16(b2, 1) // maxIdWithChars + 1 (0 chars + 1)
	buf = append(buf, b2...)
	buf = append(buf, 1)                   // enable last server button (1)
	buf = append(buf, make([]byte, 13)...) // unk padding (13)

	slog.Debug("gateway: sending SM_SERVER_LIST", "session", s.id, "servers", len(servers))
	return s.sendAuthPacket(byte(aionproto.SM_SERVER_LIST), buf)
}

// sendSMLoginFailAuth sends SM_LOGIN_FAIL using 1B opcode auth format.
func (s *Session) sendSMLoginFailAuth(reason aionproto.LoginFailReason) error {
	return s.sendAuthPacket(byte(aionproto.SM_LOGIN_FAIL), []byte{byte(reason)})
}

// sendSMPlayOKAuth sends SM_PLAY_OK (AC_PLAY_OK, 0x07).
// Matches AL-Aion SM_PLAY_OK.java: playOk1(4) + playOk2(4) + serverId(1) + padding(14).
func (s *Session) sendSMPlayOKAuth(playOk1, playOk2 int32, serverID int) error {
	buf := make([]byte, 0, 23)
	b4 := make([]byte, 4)
	binary.LittleEndian.PutUint32(b4, uint32(playOk1))
	buf = append(buf, b4...) // playOk1 (4)
	binary.LittleEndian.PutUint32(b4, uint32(playOk2))
	buf = append(buf, b4...)          // playOk2 (4)
	buf = append(buf, byte(serverID)) // serverId (1)
	buf = append(buf, make([]byte, 0x0E)...) // padding (14)
	return s.sendAuthPacket(byte(aionproto.SM_PLAY_OK), buf)
}

// encodeUTF16LE converts a string to UTF-16 LE bytes.
func encodeUTF16LE(s string) []byte {
	result := make([]byte, len(s)*2)
	for i, c := range s {
		binary.LittleEndian.PutUint16(result[i*2:], uint16(c))
	}
	return result
}

// handleCMAuthLogin decrypts and processes an incoming CM_AUTH_LOGIN packet.
//
// CM_AUTH_LOGIN structure:
//
//	[2B]  packet length
//	[2B]  opcode 0x01 (CM_AUTH_LOGIN)
//	[128B] RSA-encrypted credential block
//	[4B]  client version (informational)
//
// Returns the decrypted account name and password, or an error.
func (s *Session) handleCMAuthLogin(pkt *aionproto.Packet, rsaKP *crypto.RSAKeyPair) (account, password string, err error) {
	// Read the 128-byte RSA-encrypted credential block.
	credBlock, err := pkt.ReadBytes(crypto.CredentialBlockSize)
	if err != nil {
		return "", "", fmt.Errorf("CM_AUTH_LOGIN: read cred block: %w", err)
	}

	// Decrypt with NoPadding raw RSA.
	plain, err := rsaKP.DecryptCredentials(credBlock)
	if err != nil {
		return "", "", fmt.Errorf("CM_AUTH_LOGIN: RSA decrypt: %w", err)
	}

	account, password, err = crypto.ParseCredentials(plain)
	if err != nil {
		return "", "", fmt.Errorf("CM_AUTH_LOGIN: parse credentials: %w", err)
	}

	slog.Debug("gateway: CM_AUTH_LOGIN received", "session", s.id, "account", account)
	return account, password, nil
}

// sendSMLoginOK sends SM_LOGIN_OK with the available server list.
//
// SM_LOGIN_OK structure:
//
//	[2B]  packet length
//	[2B]  opcode 0x02
//	[4B]  account ID
//	[1B]  number of servers
//	for each server:
//	  [1B]  server ID
//	  [2B]  server name length (chars)
//	  [N*2B] server name (UTF-16 LE)
//	  [4B]  server IP (big-endian dotted-quad encoded as uint32)
//	  [4B]  server port
//	  [2B]  online count
//	  [2B]  max players
//	  [1B]  status (1=online, 0=offline)
func (s *Session) sendSMLoginOK(accountID int64, servers []ServerEntry) error {
	pkt := aionproto.NewPacket(aionproto.SM_LOGIN_OK)
	pkt.WriteUint64(uint64(accountID))
	pkt.WriteByte(byte(len(servers)))

	for _, srv := range servers {
		pkt.WriteByte(byte(srv.ID))
		pkt.WriteStringUTF16(srv.Name)
		pkt.WriteUint32(ipToUint32(srv.Host))
		pkt.WriteUint32(uint32(srv.Port))
		pkt.WriteUint16(uint16(srv.Online))
		pkt.WriteUint16(uint16(srv.MaxPlayers))
		pkt.WriteByte(1) // online
	}

	slog.Debug("gateway: sending SM_LOGIN_OK",
		"session", s.id,
		"account_id", accountID,
		"servers", len(servers))
	return s.sendPacket(pkt)
}

// sendSMLoginFail sends SM_LOGIN_FAIL with the given reason code.
func (s *Session) sendSMLoginFail(reason aionproto.LoginFailReason) error {
	pkt := aionproto.NewPacket(aionproto.SM_LOGIN_FAIL)
	pkt.WriteByte(byte(reason))
	return s.sendPacket(pkt)
}

// sendSMPlayOK sends SM_PLAY_OK carrying the session token for world entry.
//
//	[2B]  opcode 0x06
//	[4B]  server ID
//	[16B] session token (UUID bytes)
func (s *Session) sendSMPlayOK(serverID int, token []byte) error {
	pkt := aionproto.NewPacket(aionproto.SM_PLAY_OK)
	pkt.WriteUint32(uint32(serverID))
	if len(token) < 16 {
		padded := make([]byte, 16)
		copy(padded, token)
		token = padded
	}
	pkt.WriteBytes(token[:16])
	return s.sendPacket(pkt)
}

// ServerEntry describes one game server entry in the server list.
type ServerEntry struct {
	ID         int
	Name       string
	Host       string // IPv4 dotted-quad
	Port       int
	Online     int
	MaxPlayers int
}

// ipToUint32 converts a dotted-quad IPv4 string to a big-endian uint32.
// Returns 127.0.0.1 encoded as fallback on parse error.
func ipToUint32(host string) uint32 {
	var a, b, c, d byte
	n, _ := fmt.Sscanf(host, "%d.%d.%d.%d", &a, &b, &c, &d)
	if n != 4 {
		return 0x7F000001 // 127.0.0.1
	}
	return uint32(a)<<24 | uint32(b)<<16 | uint32(c)<<8 | uint32(d)
}
