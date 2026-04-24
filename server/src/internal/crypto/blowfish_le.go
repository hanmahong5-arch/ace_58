// Package crypto implements the cryptographic primitives used by the AION 5.8
// protocol: a little-endian Blowfish variant, a stateful XOR stream cipher,
// and RSA-1024 credential decryption.
//
// NCSoft's Blowfish deviates from the standard (RFC) in one key way:
// block I/O uses little-endian 32-bit word ordering instead of big-endian.
// The P-array key schedule is identical to standard Blowfish.
// This file wraps golang.org/x/crypto/blowfish to correct the byte order.
package crypto

import (
	"encoding/binary"
	"fmt"

	stdblowfish "golang.org/x/crypto/blowfish"
)

// BlowfishLE is NCSoft's non-standard Blowfish cipher.
// It uses the standard Blowfish key schedule (big-endian key mixing)
// but reads and writes cipher blocks as little-endian 32-bit word pairs.
//
// Cipher operates in ECB mode (each 8-byte block independently).
// The first 2 bytes of an AION packet (length header) are never encrypted.
type BlowfishLE struct {
	inner *stdblowfish.Cipher
}

// NewBlowfishLE creates a BlowfishLE cipher initialised with key.
// key must be 1–56 bytes; the standard static key for AION 5.8 is 16 bytes.
func NewBlowfishLE(key []byte) (*BlowfishLE, error) {
	if len(key) < 1 || len(key) > 56 {
		return nil, fmt.Errorf("blowfish_le: key length %d outside valid range [1,56]", len(key))
	}
	c, err := stdblowfish.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("blowfish_le: key schedule failed: %w", err)
	}
	return &BlowfishLE{inner: c}, nil
}

// BlockSize returns 8 (64-bit blocks, same as standard Blowfish).
func (b *BlowfishLE) BlockSize() int { return 8 }

// EncryptBlock encrypts a single 8-byte block in-place.
// src and dst may point to the same slice (in-place is safe).
func (b *BlowfishLE) EncryptBlock(dst, src []byte) {
	// Read as two little-endian 32-bit words.
	xl := binary.LittleEndian.Uint32(src[0:4])
	xr := binary.LittleEndian.Uint32(src[4:8])

	// Convert to big-endian representation for the standard cipher.
	var tmp [8]byte
	binary.BigEndian.PutUint32(tmp[0:4], xl)
	binary.BigEndian.PutUint32(tmp[4:8], xr)

	// Standard Blowfish Feistel rounds (reads/writes big-endian internally).
	b.inner.Encrypt(tmp[:], tmp[:])

	// Convert result back to little-endian.
	rl := binary.BigEndian.Uint32(tmp[0:4])
	rr := binary.BigEndian.Uint32(tmp[4:8])
	binary.LittleEndian.PutUint32(dst[0:4], rl)
	binary.LittleEndian.PutUint32(dst[4:8], rr)
}

// DecryptBlock decrypts a single 8-byte block in-place.
func (b *BlowfishLE) DecryptBlock(dst, src []byte) {
	xl := binary.LittleEndian.Uint32(src[0:4])
	xr := binary.LittleEndian.Uint32(src[4:8])

	var tmp [8]byte
	binary.BigEndian.PutUint32(tmp[0:4], xl)
	binary.BigEndian.PutUint32(tmp[4:8], xr)

	b.inner.Decrypt(tmp[:], tmp[:])

	rl := binary.BigEndian.Uint32(tmp[0:4])
	rr := binary.BigEndian.Uint32(tmp[4:8])
	binary.LittleEndian.PutUint32(dst[0:4], rl)
	binary.LittleEndian.PutUint32(dst[4:8], rr)
}

// EncryptPacket encrypts the payload of an AION packet in place.
// The first 2 bytes (length header) are skipped; the rest is encrypted
// in 8-byte ECB blocks. Any trailing bytes that don't fill a full block
// are left unencrypted (AION always pads to block boundary before calling).
func (b *BlowfishLE) EncryptPacket(pkt []byte) {
	if len(pkt) < 2 {
		return
	}
	payload := pkt[2:] // skip 2-byte length header
	for i := 0; i+8 <= len(payload); i += 8 {
		b.EncryptBlock(payload[i:i+8], payload[i:i+8])
	}
}

// DecryptPacket decrypts the payload of an AION packet in place.
// Same layout as EncryptPacket.
func (b *BlowfishLE) DecryptPacket(pkt []byte) {
	if len(pkt) < 2 {
		return
	}
	payload := pkt[2:]
	for i := 0; i+8 <= len(payload); i += 8 {
		b.DecryptBlock(payload[i:i+8], payload[i:i+8])
	}
}
