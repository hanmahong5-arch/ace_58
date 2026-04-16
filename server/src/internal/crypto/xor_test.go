package crypto

import (
	"bytes"
	"testing"
)

// TestXOR_KnownVector verifies Encode against manually computed values.
//
// With seed=1234 (0x4D2):
//   byte 0: c = 0x00 XOR 0xD2 = 0xD2; state = 0x4D2 + 0xD2 = 0x5A4
//   byte 1: c = 0x01 XOR 0xA4 = 0xA5; state = 0x5A4 + 0xA5 = 0x649
//   byte 2: c = 0x02 XOR 0x49 = 0x4B; state = 0x649 + 0x4B = 0x694
func TestXOR_KnownVector(t *testing.T) {
	x := NewXORCipher()
	data := []byte{0x00, 0x01, 0x02}
	x.Encode(data)

	want := []byte{0xD2, 0xA5, 0x4B}
	if !bytes.Equal(data, want) {
		t.Errorf("Encode: got %X, want %X", data, want)
	}

	// State after encoding 3 bytes should be 0x694.
	if x.State() != 0x694 {
		t.Errorf("state after encode: got 0x%X, want 0x694", x.State())
	}
}

// TestXOR_RoundTrip verifies that Decode(Encode(x)) == x.
func TestXOR_RoundTrip(t *testing.T) {
	original := []byte("Hello, AION 5.8 protocol!")

	enc := make([]byte, len(original))
	copy(enc, original)
	NewXORCipher().Encode(enc)

	dec := make([]byte, len(enc))
	copy(dec, enc)
	NewXORCipher().Decode(dec)

	if !bytes.Equal(dec, original) {
		t.Errorf("round-trip failed: got %q, want %q", dec, original)
	}
}

// TestXOR_DecodesKnownVector verifies Decode against the same known vector.
func TestXOR_DecodesKnownVector(t *testing.T) {
	x := NewXORCipher()
	data := []byte{0xD2, 0xA5, 0x4B}
	x.Decode(data)

	want := []byte{0x00, 0x01, 0x02}
	if !bytes.Equal(data, want) {
		t.Errorf("Decode: got %X, want %X", data, want)
	}
}

// TestXOR_StateSynchronisation confirms that encoder and decoder reach the
// same state after processing the same ciphertext stream.
func TestXOR_StateSynchronisation(t *testing.T) {
	payload := make([]byte, 64)
	for i := range payload {
		payload[i] = byte(i * 7) // arbitrary pattern
	}

	enc := make([]byte, len(payload))
	copy(enc, payload)
	encoder := NewXORCipher()
	encoder.Encode(enc)

	dec := make([]byte, len(enc))
	copy(dec, enc)
	decoder := NewXORCipher()
	decoder.Decode(dec)

	if encoder.State() != decoder.State() {
		t.Errorf("state desync: encoder=0x%X decoder=0x%X", encoder.State(), decoder.State())
	}
	if !bytes.Equal(dec, payload) {
		t.Error("decoded payload does not match original")
	}
}

// TestXOR_CustomSeed verifies custom seed initialisation.
func TestXOR_CustomSeed(t *testing.T) {
	const seed uint32 = 0xDEADBEEF
	x := NewXORCipherWithSeed(seed)
	if x.State() != seed {
		t.Errorf("initial state: got 0x%X, want 0x%X", x.State(), seed)
	}
}

// TestXOR_Reset confirms the cipher returns to the standard seed after Reset.
func TestXOR_Reset(t *testing.T) {
	x := NewXORCipher()
	x.Encode([]byte{0x01, 0x02, 0x03})
	x.Reset()
	if x.State() != xorInitialSeed {
		t.Errorf("after Reset: state=0x%X, want 0x%X", x.State(), xorInitialSeed)
	}
}

// TestXOR_EmptyInput ensures no panic on zero-length slices.
func TestXOR_EmptyInput(t *testing.T) {
	x := NewXORCipher()
	stateBefore := x.State()
	x.Encode([]byte{})
	x.Decode([]byte{})
	if x.State() != stateBefore {
		t.Error("empty input should not mutate state")
	}
}
