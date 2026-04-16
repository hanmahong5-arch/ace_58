package crypto

// XORCipher implements NCSoft's AION stateful XOR stream cipher.
//
// Algorithm (XOR-first, ADD-stored, seed 1234):
//
//	Encode byte b: c = b XOR uint8(state); state = state + uint32(c)
//	Decode byte c: b = c XOR uint8(state); state = state + uint32(c)
//
// Both encode and decode add the *encrypted* byte (c) to update state.
// This keeps encoder and decoder state perfectly synchronised across a
// shared stream of ciphertext bytes.
//
// Caution — AL-Login uses the opposite ADD order (adds the *plaintext* byte).
// Using the AL-Login order will corrupt session keys on NCSoft-compatible clients.
//
// The 5.8 client ignores the XOR checksum entirely; the server must still
// apply XOR correctly so the client can decode server-to-client packets.
type XORCipher struct {
	state uint32
}

const xorInitialSeed uint32 = 1234

// NewXORCipher creates a fresh XOR cipher with the NCSoft standard seed (1234).
func NewXORCipher() *XORCipher {
	return &XORCipher{state: xorInitialSeed}
}

// NewXORCipherWithSeed creates a cipher with a custom initial seed.
// Used for session-key-derived XOR streams after login.
func NewXORCipherWithSeed(seed uint32) *XORCipher {
	return &XORCipher{state: seed}
}

// Encode encrypts src in-place (server → client direction).
// Each byte is XOR'd with the low byte of the running state, then the
// *encrypted* result is added to state.
func (x *XORCipher) Encode(data []byte) {
	for i := range data {
		c := data[i] ^ uint8(x.state)
		x.state += uint32(c)
		data[i] = c
	}
}

// Decode decrypts src in-place (client → server direction).
// Each incoming byte is XOR'd with the low byte of the running state, then
// the *incoming encrypted* byte is added to state (mirrors the encoder).
func (x *XORCipher) Decode(data []byte) {
	for i := range data {
		enc := data[i]
		data[i] = enc ^ uint8(x.state)
		x.state += uint32(enc)
	}
}

// State returns the current cipher state (for debugging / session handoff).
func (x *XORCipher) State() uint32 { return x.state }

// Reset returns the cipher to its initial seed, ready for a new connection.
func (x *XORCipher) Reset() { x.state = xorInitialSeed }
