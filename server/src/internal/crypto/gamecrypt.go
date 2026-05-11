// Game port XOR cipher — NCSoft/AL-Aion dynamic-key encryption.
//
// Unlike the auth port (Blowfish-LE + CryptEngine), the game port uses a
// stream XOR cipher with 8-byte keys that evolve after every packet.
// A 64-byte static key provides additional entropy per-byte.
//
// Key derivation: a single int32 baseKey → 8-byte key = [baseKey LE 4 bytes] + [0xa1 0x6c 0x54 0x87].
// Enciphered key sent to client: (baseKey ^ 0xCD92E4DF) + 0x3FF2CCCF.
package crypto

import (
	"encoding/binary"
	"sync"
)

// 64-byte static XOR key shared by all AION game connections.
var gameStaticKey = []byte("nKO/WctQ0AVLbpzfBkS6NevDYT8ourG5CRlmdjyJ72aswx4EPq1UgZhFMXH?3iI9")

// Static validation bytes embedded in packets.
// These values are version-dependent (4.8: server=0x44/client=0x65; 5.8: server=0x44/client=0x7D).
const (
	ServerPacketCode byte = 0x44
	ClientPacketCode byte = 0x7D // 5.8 uses 0x7D, not 0x65
)

// GameCrypt handles XOR encryption/decryption for one game port session.
// Server and client keys evolve independently after each packet.
type GameCrypt struct {
	mu        sync.Mutex
	serverKey [8]byte // server→client direction
	clientKey [8]byte // client��server direction
	enabled   bool    // false until first server packet (SM_KEY) is sent
}

// NewGameCrypt creates a GameCrypt from a 32-bit base key.
// The same baseKey seeds both server and client keys (initially identical).
func NewGameCrypt(baseKey int32) *GameCrypt {
	gc := &GameCrypt{}
	gc.serverKey[0] = byte(baseKey)
	gc.serverKey[1] = byte(baseKey >> 8)
	gc.serverKey[2] = byte(baseKey >> 16)
	gc.serverKey[3] = byte(baseKey >> 24)
	gc.serverKey[4] = 0xa1
	gc.serverKey[5] = 0x6c
	gc.serverKey[6] = 0x54
	gc.serverKey[7] = 0x87
	gc.clientKey = gc.serverKey
	return gc
}

// EncipherKey returns the obfuscated key to send to the client in SM_KEY.
// The constants are version-dependent (last byte = version & 0xFF):
//   4.8: (key ^ 0xCD92E4DF) + 0x3FF2CCCF
//   5.8: (key ^ 0xCD92E4D5) + 0x3FF2CCD7
func EncipherKey(baseKey int32, versionByte byte) int32 {
	xorConst := uint32(0xCD92E400) | uint32(versionByte)
	addConst := encipherAddConst(versionByte)
	return int32(uint32(baseKey)^xorConst) + int32(addConst)
}

// encipherAddConst returns the ADD constant for key enciphering based on version byte.
func encipherAddConst(vb byte) uint32 {
	switch vb {
	case 0xD5: // 5.8 (v213)
		return 0x3FF2CCD7
	default: // 4.8 (v207) and similar
		return 0x3FF2CCCF
	}
}

// Enable activates encryption for subsequent Encrypt calls.
// The first server packet (SM_KEY itself) is NOT encrypted.
func (gc *GameCrypt) Enable() {
	gc.mu.Lock()
	gc.enabled = true
	gc.mu.Unlock()
}

// IsEnabled returns whether encryption is active.
func (gc *GameCrypt) IsEnabled() bool {
	gc.mu.Lock()
	defer gc.mu.Unlock()
	return gc.enabled
}

// Encrypt applies server→client XOR encryption to data (packet body after 2B size header).
// Returns false if encryption is not yet enabled (SM_KEY was not yet sent).
// After encryption, the server key evolves by adding the data length.
func (gc *GameCrypt) Encrypt(data []byte) bool {
	gc.mu.Lock()
	defer gc.mu.Unlock()

	if !gc.enabled {
		gc.enabled = true
		return false // SM_KEY — skip encryption
	}

	size := len(data)
	if size == 0 {
		return true
	}

	// XOR-chain encrypt
	data[0] ^= gc.serverKey[0]
	prev := data[0]
	for i := 1; i < size; i++ {
		data[i] ^= gameStaticKey[i&63] ^ gc.serverKey[i&7] ^ prev
		prev = data[i]
	}

	// Evolve key: treat 8 bytes as int64 LE, add size
	gc.evolveKey(&gc.serverKey, size)
	return true
}

// Decrypt applies client→server XOR decryption to data (packet body after 2B size header).
// Returns true if the packet passes structural validation (static code + checksum).
// After decryption, the client key evolves by adding the data length.
func (gc *GameCrypt) Decrypt(data []byte) bool {
	gc.mu.Lock()
	defer gc.mu.Unlock()

	size := len(data)
	if size < 5 {
		return false
	}

	// XOR-chain decrypt (prev = encrypted byte before decryption)
	prev := int(data[0])
	data[0] ^= gc.clientKey[0]
	for i := 1; i < size; i++ {
		curr := int(data[i] & 0xff)
		data[i] ^= gameStaticKey[i&63] ^ gc.clientKey[i&7] ^ byte(prev)
		prev = curr
	}

	// Validate client packet structure
	valid := gc.validateClient(data)
	if valid {
		gc.evolveKey(&gc.clientKey, size)
	}
	return valid
}

// validateClient checks the structural invariants of a decrypted client packet body:
// - byte[2] == 0x65 (staticClientPacketCode)
// - int16[0:2] == ~int16[3:5] (opcode checksum)
func (gc *GameCrypt) validateClient(data []byte) bool {
	if len(data) < 5 {
		return false
	}
	if data[2] != ClientPacketCode {
		return false
	}
	opcode := binary.LittleEndian.Uint16(data[0:2])
	check := binary.LittleEndian.Uint16(data[3:5])
	return opcode == ^check
}

// evolveKey treats the 8-byte key as a little-endian int64 and adds size.
func (gc *GameCrypt) evolveKey(key *[8]byte, size int) {
	v := binary.LittleEndian.Uint64(key[:])
	v += uint64(size)
	binary.LittleEndian.PutUint64(key[:], v)
}

// EncodeServerOpcode obfuscates a server→client opcode for wire transmission.
// Formula is version-dependent: 5.8 uses (op + 0xD5) ^ 0xD5, 4.8 uses (op + version) ^ 0xDF.
func EncodeServerOpcode(rawOpcode uint16, internalVersion int) uint16 {
	vb := byte(internalVersion & 0xFF)
	xorMask := opcodeXORMask(vb)
	return uint16((int(rawOpcode) + int(vb)) ^ int(xorMask))
}

// DecodeClientOpcode deobfuscates a client→server opcode from the wire.
// 5.8 formula: (((op ^ 0xD5) - 0x0E) ^ 0xD5) - 0xD5
// 4.8 formula: (((op ^ 0xEF) - 0x0C) ^ 0xEF) - VERSION
func DecodeClientOpcode(encodedOpcode uint16, internalVersion int) uint16 {
	vb := int(byte(internalVersion & 0xFF))
	xor := int(opcodeXORMask(byte(vb)))
	sub := clientDecodeSub(byte(vb))
	v := int(encodedOpcode) ^ xor
	v -= sub
	v ^= xor
	v -= vb
	return uint16(v & 0xFFFF)
}

// clientDecodeSub returns the subtraction constant for client opcode decoding.
func clientDecodeSub(versionByte byte) int {
	switch versionByte {
	case 0xD5: // 5.8
		return 0x0E
	default: // 4.8 and similar
		return 0x0C
	}
}

// opcodeXORMask returns the XOR mask for opcode obfuscation.
func opcodeXORMask(versionByte byte) byte {
	switch versionByte {
	case 0xD5: // 5.8 (v213): XOR mask = 0xD5 (same as version byte)
		return 0xD5
	case 0xCE: // 4.7.5 (v206)
		return 0xDF
	case 0xCB: // 4.5 (v203)
		return 0xDB
	default:
		return 0xDF // fallback to 4.8 style
	}
}
