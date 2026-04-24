package aionproto

import (
	"bytes"
	"encoding/binary"
	"io"
	"testing"
)

// TestNewPacketOpcode covers the round-trip of Opcode() against the
// little-endian field written by NewPacket.
func TestNewPacketOpcode(t *testing.T) {
	p := NewPacket(0x1234)
	if got := p.Opcode(); got != 0x1234 {
		t.Fatalf("Opcode = 0x%X, want 0x1234", got)
	}
}

// TestOpcodeOnShortBuffer exercises the defensive guard at the top of Opcode().
func TestOpcodeOnShortBuffer(t *testing.T) {
	p := &Packet{buf: []byte{0x01}}
	if got := p.Opcode(); got != 0 {
		t.Fatalf("Opcode on short buf = %d, want 0", got)
	}
}

// TestWriteHelpersAndBytesPadding validates every Write* helper and the
// BlockSize padding behaviour that Bytes() applies.
func TestWriteHelpersAndBytesPadding(t *testing.T) {
	p := NewPacket(0x0042)
	_ = p.WriteByte(0x7F)
	p.WriteUint16(0xBEEF)
	p.WriteUint32(0xDEADBEEF)
	p.WriteUint64(0x1122334455667788)
	p.WriteFloat32(1.5)
	p.WriteBytes([]byte{0xAA, 0xBB})
	p.WriteStringUTF16("hi")

	out := p.Bytes()
	// Payload (excluding 2-byte header) must align to BlockSize.
	if (len(out)-HeaderSize)%BlockSize != 0 {
		t.Fatalf("padded length %d not multiple of %d after header", len(out)-HeaderSize, BlockSize)
	}
	// Declared length field must equal len(out).
	declared := int(binary.LittleEndian.Uint16(out[:HeaderSize]))
	if declared != len(out) {
		t.Fatalf("declared length %d != len(out) %d", declared, len(out))
	}
}

// TestBytesNoPaddingWhenAlreadyAligned ensures Bytes() does not over-pad.
func TestBytesNoPaddingWhenAlreadyAligned(t *testing.T) {
	p := NewPacket(0x01)           // 4 bytes (header+opcode)
	p.WriteUint32(0x12345678)      // +4 → payload = 6 bytes (not aligned)
	p.WriteUint16(0xABCD)          // +2 → payload = 8 bytes (aligned)
	out := p.Bytes()
	if (len(out)-HeaderSize)%BlockSize != 0 {
		t.Fatalf("not aligned: %d", len(out))
	}
	// Second call must not grow.
	n := len(out)
	out2 := p.Bytes()
	// The second call re-pads on a non-aligned boundary, but since our
	// write-path already terminated at alignment, it stays the same length.
	if len(out2) != n {
		t.Fatalf("second Bytes() grew from %d to %d", n, len(out2))
	}
}

// TestFromBytesErrors covers the three rejection branches in FromBytes.
func TestFromBytesErrors(t *testing.T) {
	// Too short (< MinPacketSize).
	if _, err := FromBytes([]byte{0x00, 0x00}); err == nil {
		t.Error("expected error for short buffer")
	}
	// Declared length out of range (below MinPacketSize).
	bad := []byte{0x02, 0x00, 0x00, 0x00}
	if _, err := FromBytes(bad); err == nil {
		t.Error("expected error for under-minimum declared length")
	}
	// Declared length exceeds buffer length.
	short := []byte{0x10, 0x00, 0x00, 0x00}
	if _, err := FromBytes(short); err == nil {
		t.Error("expected error for truncated buffer")
	}
}

// TestReadHelpersRoundTrip encodes every primitive via Write*, then
// decodes via FromBytes + Read*, asserting identity.
func TestReadHelpersRoundTrip(t *testing.T) {
	p := NewPacket(0x00AA)
	_ = p.WriteByte(0x5A)
	p.WriteUint16(0xFACE)
	p.WriteUint32(0xCAFEBABE)
	p.WriteUint64(0x0123456789ABCDEF)
	p.WriteFloat32(2.5)
	p.WriteBytes([]byte{0x10, 0x20, 0x30})
	raw := p.Bytes()

	rp, err := FromBytes(raw)
	if err != nil {
		t.Fatalf("FromBytes: %v", err)
	}
	if rp.Opcode() != 0x00AA {
		t.Fatalf("opcode mismatch")
	}
	if b, _ := rp.ReadByte(); b != 0x5A {
		t.Errorf("byte")
	}
	if v, _ := rp.ReadUint16(); v != 0xFACE {
		t.Errorf("u16")
	}
	if v, _ := rp.ReadUint32(); v != 0xCAFEBABE {
		t.Errorf("u32")
	}
	if v, _ := rp.ReadUint64(); v != 0x0123456789ABCDEF {
		t.Errorf("u64")
	}
	if f, _ := rp.ReadFloat32(); f != 2.5 {
		t.Errorf("f32 = %v", f)
	}
	bs, err := rp.ReadBytes(3)
	if err != nil || !bytes.Equal(bs, []byte{0x10, 0x20, 0x30}) {
		t.Errorf("bytes=%x err=%v", bs, err)
	}
	// Remaining covers padding tail (zero or more pad bytes).
	if rp.Remaining() < 0 {
		t.Errorf("negative remaining")
	}
}

// TestReadPastEnd exercises all Read* EOF branches.
func TestReadPastEnd(t *testing.T) {
	p := NewPacket(0x01)
	raw := p.Bytes()
	// FromBytes so rpos sits at end of opcode; any Read* should fail as the
	// packet carries only pad bytes (which we treat as unread payload).
	rp, _ := FromBytes(raw)
	// Drain any pad bytes to force EOF on subsequent reads.
	for rp.Remaining() > 0 {
		_, _ = rp.ReadByte()
	}
	if _, err := rp.ReadByte(); err != io.ErrUnexpectedEOF {
		t.Errorf("ReadByte past end: want EOF, got %v", err)
	}
	if _, err := rp.ReadUint16(); err != io.ErrUnexpectedEOF {
		t.Errorf("ReadUint16 past end")
	}
	if _, err := rp.ReadUint32(); err != io.ErrUnexpectedEOF {
		t.Errorf("ReadUint32 past end")
	}
	if _, err := rp.ReadUint64(); err != io.ErrUnexpectedEOF {
		t.Errorf("ReadUint64 past end")
	}
	if _, err := rp.ReadBytes(1); err != io.ErrUnexpectedEOF {
		t.Errorf("ReadBytes past end")
	}
}

// TestRawBufferAlias verifies RawBuffer() returns the live slice (not a copy)
// so crypto layers can encrypt in place.
func TestRawBufferAlias(t *testing.T) {
	p := NewPacket(0x01)
	raw := p.RawBuffer()
	raw[2] = 0xFF
	if p.Opcode() != 0x00FF {
		t.Errorf("RawBuffer should alias the packet buffer")
	}
}

// TestReadPacketFromConn covers the canonical gateway read loop entry.
func TestReadPacketFromConn(t *testing.T) {
	// Build a valid 8-byte packet.
	p := NewPacket(0x0055)
	p.WriteUint32(0xAABBCCDD)
	raw := p.Bytes()

	rd := bytes.NewReader(raw)
	got, err := ReadPacketFromConn(rd)
	if err != nil {
		t.Fatalf("ReadPacketFromConn: %v", err)
	}
	if !bytes.Equal(got, raw) {
		t.Errorf("round-trip mismatch")
	}

	// Truncated header.
	if _, err := ReadPacketFromConn(bytes.NewReader(nil)); err == nil {
		t.Error("expected error on empty reader")
	}
	// Invalid declared length.
	if _, err := ReadPacketFromConn(bytes.NewReader([]byte{0x00, 0x00})); err == nil {
		t.Error("expected error on declared length 0")
	}
	// Truncated body.
	trunc := make([]byte, 2)
	binary.LittleEndian.PutUint16(trunc, 16)
	if _, err := ReadPacketFromConn(bytes.NewReader(trunc)); err == nil {
		t.Error("expected error on truncated body")
	}
}
