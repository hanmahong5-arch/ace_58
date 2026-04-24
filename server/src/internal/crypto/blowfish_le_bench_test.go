package crypto

import "testing"

// BenchmarkBFEncryptBlock measures a single 8-byte Blowfish-LE block encrypt.
// This runs once per 8 bytes of every outbound packet's payload, so its cost
// dominates gateway CPU at high CCU.
func BenchmarkBFEncryptBlock(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	block := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher.EncryptBlock(block, block)
	}
}

// BenchmarkBFDecryptBlock measures a single 8-byte Blowfish-LE block decrypt.
// Inbound packets from clients are decrypted block-by-block in the gateway.
func BenchmarkBFDecryptBlock(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	block := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF}
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher.DecryptBlock(block, block)
	}
}

// BenchmarkBFEncryptPayload1KB benchmarks encryption of a 1 KiB packet payload
// (typical size for position broadcast / chat). Payload is pre-allocated so the
// hot loop measures only cipher cost.
func BenchmarkBFEncryptPayload1KB(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	// 2-byte header + 1024-byte payload (multiple of 8).
	pkt := make([]byte, 2+1024)
	for i := range pkt {
		pkt[i] = byte(i)
	}
	b.SetBytes(int64(len(pkt) - 2))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher.EncryptPacket(pkt)
	}
}

// BenchmarkBFEncryptPayload16KB benchmarks a 16 KiB payload — worst-case
// broadcast packet (e.g. inventory sync, large NPC list).
func BenchmarkBFEncryptPayload16KB(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	pkt := make([]byte, 2+16*1024)
	for i := range pkt {
		pkt[i] = byte(i)
	}
	b.SetBytes(int64(len(pkt) - 2))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher.EncryptPacket(pkt)
	}
}

// BenchmarkBFEncryptPayloadParallel estimates multi-core cipher throughput
// to inform 1800-CCU capacity planning. Each goroutine owns a private
// packet buffer so the measurement reflects pure CPU parallelism (no
// contention, no false sharing). The cipher is stateless after key
// schedule, so a single *BlowfishLE is safe to share across goroutines.
func BenchmarkBFEncryptPayloadParallel(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	const payloadSize = 1024
	b.SetBytes(int64(payloadSize))
	b.ReportAllocs()
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		pkt := make([]byte, 2+payloadSize)
		for i := range pkt {
			pkt[i] = byte(i)
		}
		for pb.Next() {
			cipher.EncryptPacket(pkt)
		}
	})
}
