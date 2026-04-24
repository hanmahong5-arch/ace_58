package crypto

import "testing"

// BenchmarkXOREncode measures stateful XOR encoding over a 1 KiB buffer.
// XOR runs on every packet (after BF encryption) in the gateway, so its
// throughput matters even though it is simpler than Blowfish.
func BenchmarkXOREncode(b *testing.B) {
	const size = 1024
	// Allocate buffer outside the hot loop; re-seed cipher each iteration
	// to avoid state drift that would distort steady-state numbers.
	buf := make([]byte, size)
	for i := range buf {
		buf[i] = byte(i)
	}
	b.SetBytes(int64(size))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher := NewXORCipher()
		cipher.Encode(buf)
	}
}

// BenchmarkXORDecode measures stateful XOR decoding over a 1 KiB buffer.
// Mirrors Encode; included because decode and encode have distinct data flow
// (decode uses the encrypted byte for state update, encode uses the result).
func BenchmarkXORDecode(b *testing.B) {
	const size = 1024
	buf := make([]byte, size)
	for i := range buf {
		buf[i] = byte(i)
	}
	b.SetBytes(int64(size))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher := NewXORCipher()
		cipher.Decode(buf)
	}
}
