package crypto

import (
	"bytes"
	"encoding/hex"
	"testing"
)

// staticKey16 is the AION 5.8 static Blowfish key from config (hex-decoded).
// In production this is loaded from gateway.toml; hardcoded here only for testing.
var staticKey16, _ = hex.DecodeString("6B60CB5B82CE90B1CC2B6C556C6C6C6C")

// TestBlowfishLE_RoundTrip verifies that Decrypt(Encrypt(x)) == x for arbitrary input.
func TestBlowfishLE_RoundTrip(t *testing.T) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		t.Fatalf("NewBlowfishLE: %v", err)
	}

	cases := [][]byte{
		{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
		{0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF},
		{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF},
		{0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE},
	}

	for _, plain := range cases {
		var enc [8]byte
		var dec [8]byte

		cipher.EncryptBlock(enc[:], plain)
		cipher.DecryptBlock(dec[:], enc[:])

		if !bytes.Equal(dec[:], plain) {
			t.Errorf("round-trip failed: input=%X enc=%X got=%X", plain, enc, dec)
		}
	}
}

// TestBlowfishLE_Deterministic verifies that the same input always produces
// the same output (cipher is deterministic / ECB mode).
func TestBlowfishLE_Deterministic(t *testing.T) {
	c1, _ := NewBlowfishLE(staticKey16)
	c2, _ := NewBlowfishLE(staticKey16)

	block := []byte{0xAA, 0xBB, 0xCC, 0xDD, 0x11, 0x22, 0x33, 0x44}
	var out1, out2 [8]byte

	c1.EncryptBlock(out1[:], block)
	c2.EncryptBlock(out2[:], block)

	if !bytes.Equal(out1[:], out2[:]) {
		t.Errorf("same key+input produced different outputs: %X vs %X", out1, out2)
	}
}

// TestBlowfishLE_DifferentKeys confirms that two different keys produce different output.
func TestBlowfishLE_DifferentKeys(t *testing.T) {
	key1 := make([]byte, 16)
	key2 := make([]byte, 16)
	key2[0] = 0xFF // one byte different

	c1, _ := NewBlowfishLE(key1)
	c2, _ := NewBlowfishLE(key2)

	block := []byte{0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
	var out1, out2 [8]byte
	c1.EncryptBlock(out1[:], block)
	c2.EncryptBlock(out2[:], block)

	if bytes.Equal(out1[:], out2[:]) {
		t.Error("different keys produced identical output — cipher is broken")
	}
}

// TestBlowfishLE_PacketEncryption tests multi-block packet encrypt/decrypt.
// Simulates a 20-byte AION packet: 2-byte header + 16-byte payload (2 full blocks).
func TestBlowfishLE_PacketEncryption(t *testing.T) {
	cipher, _ := NewBlowfishLE(staticKey16)

	// Build a fake packet: [0x14, 0x00] (length=20) + 16 bytes of payload
	pkt := make([]byte, 20)
	pkt[0] = 0x14 // length low byte
	pkt[1] = 0x00 // length high byte
	for i := 2; i < 20; i++ {
		pkt[i] = byte(i)
	}

	original := make([]byte, len(pkt))
	copy(original, pkt)

	cipher.EncryptPacket(pkt)

	// Header must be unchanged.
	if pkt[0] != original[0] || pkt[1] != original[1] {
		t.Error("EncryptPacket modified the length header")
	}

	// Payload must have changed.
	if bytes.Equal(pkt[2:], original[2:]) {
		t.Error("EncryptPacket produced no ciphertext change")
	}

	// Decrypt must recover original.
	cipher.DecryptPacket(pkt)
	if !bytes.Equal(pkt, original) {
		t.Errorf("packet round-trip failed: got %X, want %X", pkt, original)
	}
}

// TestBlowfishLE_InvalidKeyLength confirms error on out-of-range key sizes.
func TestBlowfishLE_InvalidKeyLength(t *testing.T) {
	_, err := NewBlowfishLE(nil)
	if err == nil {
		t.Error("expected error for nil key")
	}

	longKey := make([]byte, 57) // 57 bytes > 56 maximum
	_, err = NewBlowfishLE(longKey)
	if err == nil {
		t.Error("expected error for 57-byte key")
	}
}
