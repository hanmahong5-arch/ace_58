package aionproto

import "testing"

// BenchmarkPacketEncode measures a realistic outbound packet build:
// a handful of typed writes plus final Bytes() (padding + length patch).
// This is the shape of a position-broadcast or stat-update packet.
func BenchmarkPacketEncode(b *testing.B) {
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		p := NewPacket(0x1234)
		p.WriteUint32(uint32(i))
		p.WriteFloat32(1234.5)
		p.WriteFloat32(6789.0)
		p.WriteFloat32(0.0)
		_ = p.WriteByte(0x07)
		p.WriteUint16(0xBEEF)
		_ = p.Bytes()
	}
}

// BenchmarkPacketDecode measures FromBytes + a sequence of typed reads,
// representing a CM_MOVE-style inbound packet's parse cost.
func BenchmarkPacketDecode(b *testing.B) {
	// Build a fixture once.
	src := NewPacket(0x1234)
	src.WriteUint32(0xDEADBEEF)
	src.WriteFloat32(1234.5)
	src.WriteFloat32(6789.0)
	src.WriteFloat32(0.0)
	_ = src.WriteByte(0x07)
	src.WriteUint16(0xBEEF)
	raw := src.Bytes()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		p, err := FromBytes(raw)
		if err != nil {
			b.Fatalf("FromBytes: %v", err)
		}
		_, _ = p.ReadUint32()
		_, _ = p.ReadFloat32()
		_, _ = p.ReadFloat32()
		_, _ = p.ReadFloat32()
		_, _ = p.ReadByte()
		_, _ = p.ReadUint16()
	}
}
