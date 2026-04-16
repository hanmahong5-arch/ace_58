package main

import (
	"fmt"
	"log/slog"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
)

// sendSMKey sends the SM_KEY packet to the client.
// This is the first packet sent on the auth connection (:2108).
// It is deliberately unencrypted (BF cipher not yet active).
//
// SM_KEY structure (Phase S-1 full implementation):
//
//	[2B]  total packet length
//	[2B]  opcode 0x00 (SM_KEY)
//	[4B]  scramble header (NCSoft-specific)
//	[128B] RSA-1024 public key modulus (big-endian)
//	[16B]  static Blowfish key (sent clear so client can begin BF)
//	[1B]   country code (5 = China)
//
// After the client receives this packet it enables BF-LE encryption for all
// subsequent CM_* packets, using the static BF key it just received.
func (s *Session) sendSMKey(rsaMod []byte, bfStaticKey []byte, country int) error {
	pkt := aionproto.NewPacket(aionproto.SM_KEY)

	// Scramble header (4 zero bytes in our implementation — NCSoft used
	// a random 4-byte value for obfuscation; the client ignores the content).
	pkt.WriteUint32(0)

	// RSA-1024 public key modulus (128 bytes, big-endian).
	if len(rsaMod) != crypto.CredentialBlockSize {
		return fmt.Errorf("sendSMKey: RSA modulus must be %d bytes, got %d",
			crypto.CredentialBlockSize, len(rsaMod))
	}
	pkt.WriteBytes(rsaMod)

	// Static Blowfish key (16 bytes).
	if len(bfStaticKey) != 16 {
		return fmt.Errorf("sendSMKey: BF key must be 16 bytes, got %d", len(bfStaticKey))
	}
	pkt.WriteBytes(bfStaticKey)

	// Country code (1 byte).
	pkt.WriteByte(byte(country))

	slog.Debug("gateway: sending SM_KEY", "session", s.id)
	return s.sendPacket(pkt)
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
