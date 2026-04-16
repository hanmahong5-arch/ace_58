package aionproto

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"
)

const (
	// HeaderSize is the length of the 2-byte packet length prefix.
	HeaderSize = 2

	// MinPacketSize is the smallest valid packet (header + opcode).
	MinPacketSize = HeaderSize + 2

	// MaxPacketSize is the largest single AION packet (64 KiB - 1).
	// Packets larger than this indicate a protocol error or attack.
	MaxPacketSize = 0xFFFF

	// BlockSize is the BF cipher block size; packets are padded to this.
	BlockSize = 8
)

// Packet is a decoded AION packet with convenience read/write helpers.
// The underlying buffer includes the 2-byte length header at [0:2],
// the 2-byte opcode at [2:4], and payload at [4:].
type Packet struct {
	buf  []byte
	rpos int // current read position within buffer (starts after opcode at offset 4)
}

// NewPacket creates a writable packet with the given opcode.
// Call the Write* methods to append fields, then call Bytes() to get
// the final wire-format slice (including length header and padding).
func NewPacket(opcode uint16) *Packet {
	p := &Packet{
		buf:  make([]byte, HeaderSize+2, 64), // header + opcode; grow on writes
		rpos: HeaderSize + 2,
	}
	binary.LittleEndian.PutUint16(p.buf[HeaderSize:], opcode)
	return p
}

// Opcode returns the packet's opcode (little-endian uint16 at offset 2).
func (p *Packet) Opcode() uint16 {
	if len(p.buf) < MinPacketSize {
		return 0
	}
	return binary.LittleEndian.Uint16(p.buf[HeaderSize:])
}

// Bytes returns the complete packet bytes suitable for transmission.
// The length header is updated, and zero-padding is appended so the
// payload length (bytes after the 2-byte header) is a multiple of BlockSize.
func (p *Packet) Bytes() []byte {
	// Pad so (total - HeaderSize) % BlockSize == 0.
	payloadLen := len(p.buf) - HeaderSize
	if rem := payloadLen % BlockSize; rem != 0 {
		p.buf = append(p.buf, make([]byte, BlockSize-rem)...)
	}
	// Update the 2-byte length field (total length including header).
	binary.LittleEndian.PutUint16(p.buf[:HeaderSize], uint16(len(p.buf)))
	return p.buf
}

// --- Write helpers (append to packet) ---

// WriteByte appends a single byte.
// Returns nil to satisfy the io.ByteWriter interface.
func (p *Packet) WriteByte(v byte) error {
	p.buf = append(p.buf, v)
	return nil
}

// WriteUint16 appends a uint16 in little-endian order.
func (p *Packet) WriteUint16(v uint16) {
	var tmp [2]byte
	binary.LittleEndian.PutUint16(tmp[:], v)
	p.buf = append(p.buf, tmp[:]...)
}

// WriteUint32 appends a uint32 in little-endian order.
func (p *Packet) WriteUint32(v uint32) {
	var tmp [4]byte
	binary.LittleEndian.PutUint32(tmp[:], v)
	p.buf = append(p.buf, tmp[:]...)
}

// WriteUint64 appends a uint64 in little-endian order.
func (p *Packet) WriteUint64(v uint64) {
	var tmp [8]byte
	binary.LittleEndian.PutUint64(tmp[:], v)
	p.buf = append(p.buf, tmp[:]...)
}

// WriteFloat32 appends a float32 as its IEEE 754 bit pattern (LE).
func (p *Packet) WriteFloat32(v float32) {
	p.WriteUint32(math.Float32bits(v))
}

// WriteBytes appends raw bytes.
func (p *Packet) WriteBytes(b []byte) {
	p.buf = append(p.buf, b...)
}

// WriteStringUTF16 appends a null-terminated UTF-16 LE string.
// AION string fields use UTF-16 LE encoding with a 2-byte null terminator.
func (p *Packet) WriteStringUTF16(s string) {
	for _, r := range s {
		var tmp [2]byte
		binary.LittleEndian.PutUint16(tmp[:], uint16(r))
		p.buf = append(p.buf, tmp[:]...)
	}
	p.buf = append(p.buf, 0x00, 0x00) // null terminator
}

// --- Read helpers (consume from a received packet) ---

// FromBytes wraps an already-received packet byte slice for reading.
// The slice must include the 2-byte length header.
func FromBytes(raw []byte) (*Packet, error) {
	if len(raw) < MinPacketSize {
		return nil, fmt.Errorf("packet: too short (%d bytes)", len(raw))
	}
	declared := int(binary.LittleEndian.Uint16(raw[:HeaderSize]))
	if declared < MinPacketSize || declared > MaxPacketSize {
		return nil, fmt.Errorf("packet: declared length %d out of range [%d,%d]",
			declared, MinPacketSize, MaxPacketSize)
	}
	if len(raw) < declared {
		return nil, fmt.Errorf("packet: buffer has %d bytes, header declares %d",
			len(raw), declared)
	}
	return &Packet{
		buf:  raw[:declared],
		rpos: HeaderSize + 2, // skip header + opcode; payload reads start here
	}, nil
}

// ReadByte reads the next byte from the payload.
func (p *Packet) ReadByte() (byte, error) {
	if p.rpos >= len(p.buf) {
		return 0, io.ErrUnexpectedEOF
	}
	v := p.buf[p.rpos]
	p.rpos++
	return v, nil
}

// ReadUint16 reads the next 2 bytes as uint16 LE.
func (p *Packet) ReadUint16() (uint16, error) {
	if p.rpos+2 > len(p.buf) {
		return 0, io.ErrUnexpectedEOF
	}
	v := binary.LittleEndian.Uint16(p.buf[p.rpos:])
	p.rpos += 2
	return v, nil
}

// ReadUint32 reads the next 4 bytes as uint32 LE.
func (p *Packet) ReadUint32() (uint32, error) {
	if p.rpos+4 > len(p.buf) {
		return 0, io.ErrUnexpectedEOF
	}
	v := binary.LittleEndian.Uint32(p.buf[p.rpos:])
	p.rpos += 4
	return v, nil
}

// ReadUint64 reads the next 8 bytes as uint64 LE.
func (p *Packet) ReadUint64() (uint64, error) {
	if p.rpos+8 > len(p.buf) {
		return 0, io.ErrUnexpectedEOF
	}
	v := binary.LittleEndian.Uint64(p.buf[p.rpos:])
	p.rpos += 8
	return v, nil
}

// ReadFloat32 reads the next 4 bytes as float32 (IEEE 754 LE).
func (p *Packet) ReadFloat32() (float32, error) {
	u, err := p.ReadUint32()
	return math.Float32frombits(u), err
}

// ReadBytes reads exactly n raw bytes.
func (p *Packet) ReadBytes(n int) ([]byte, error) {
	if p.rpos+n > len(p.buf) {
		return nil, io.ErrUnexpectedEOF
	}
	out := make([]byte, n)
	copy(out, p.buf[p.rpos:p.rpos+n])
	p.rpos += n
	return out, nil
}

// Remaining returns the number of unread payload bytes.
func (p *Packet) Remaining() int {
	r := len(p.buf) - p.rpos
	if r < 0 {
		return 0
	}
	return r
}

// RawBuffer returns the underlying byte slice for direct manipulation
// (e.g., passing to the BF-LE cipher for encryption).
func (p *Packet) RawBuffer() []byte { return p.buf }

// ReadPacketFromConn reads exactly one packet from an io.Reader.
// It first reads the 2-byte length header, then reads the rest of the packet.
// This is the canonical entry point for the gateway's read loop.
func ReadPacketFromConn(r io.Reader) ([]byte, error) {
	var header [HeaderSize]byte
	if _, err := io.ReadFull(r, header[:]); err != nil {
		return nil, fmt.Errorf("packet: read header: %w", err)
	}

	total := int(binary.LittleEndian.Uint16(header[:]))
	if total < MinPacketSize || total > MaxPacketSize {
		return nil, fmt.Errorf("packet: invalid declared length %d", total)
	}

	buf := make([]byte, total)
	copy(buf[:HeaderSize], header[:])

	if _, err := io.ReadFull(r, buf[HeaderSize:]); err != nil {
		return nil, fmt.Errorf("packet: read body: %w", err)
	}
	return buf, nil
}
