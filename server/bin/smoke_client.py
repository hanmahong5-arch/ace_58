"""Phase S-19 backend smoke client.

Connects to the AION 5.8 protocol gateway on 127.0.0.1:2108, reads the
SM_KEY packet, and validates its structure:

  [2B]  total length (little-endian)
  [2B]  opcode 0x00 (SM_KEY)
  [4B]  scramble header (zeros)
  [128B] RSA-1024 public key modulus (big-endian)
  [16B]  static Blowfish key
  [1B]  country code (5 = China)
  [1B]  padding byte (payload aligned to BF 8-byte block)

Total expected bytes = 154 (payload padded from 151 → 152).

Used as a sanity check after Phase S-19 build to confirm the gateway
brings up cleanly and emits a well-formed SM_KEY without needing the
real 5.8 client to validate the wire format.
"""
import socket
import struct
import sys

HOST = "127.0.0.1"
AUTH_PORT = 2108
_RAW_PAYLOAD = 2 + 4 + 128 + 16 + 1   # 151
_BLOCK = 8
_PAD = (-_RAW_PAYLOAD) % _BLOCK
EXPECTED_TOTAL_LEN = 2 + _RAW_PAYLOAD + _PAD  # = 154

def main() -> int:
    with socket.create_connection((HOST, AUTH_PORT), timeout=5.0) as s:
        # Read total length (LE u16) then the rest of the packet.
        header = s.recv(2)
        if len(header) != 2:
            print(f"FAIL: expected 2 byte length header, got {len(header)}")
            return 1
        total_len = struct.unpack_from("<H", header)[0]
        print(f"length header (LE u16) = {total_len} (expected {EXPECTED_TOTAL_LEN})")

        body = b""
        while len(body) < total_len - 2:
            chunk = s.recv(total_len - 2 - len(body))
            if not chunk:
                break
            body += chunk

        if len(body) + 2 != total_len:
            print(f"FAIL: short read; got {len(body)+2} of {total_len} bytes")
            return 1

        opcode = struct.unpack_from("<H", body, 0)[0]
        scramble = struct.unpack_from("<I", body, 2)[0]
        rsa_mod = body[6:6+128]
        bf_key  = body[6+128:6+128+16]
        country = body[6+128+16]

        print(f"opcode = 0x{opcode:02X} (expected 0x00 SM_KEY)")
        print(f"scramble = 0x{scramble:08X}")
        print(f"RSA modulus (first 16) = {rsa_mod[:16].hex()}")
        print(f"RSA modulus (last 16)  = {rsa_mod[-16:].hex()}")
        print(f"BF static key          = {bf_key.hex()}")
        print(f"country code           = {country}")

        ok = True
        if total_len != EXPECTED_TOTAL_LEN:
            print(f"FAIL: total_len mismatch")
            ok = False
        if opcode != 0x00:
            print(f"FAIL: opcode mismatch")
            ok = False
        if country != 5:
            print(f"FAIL: country mismatch (want 5, got {country})")
            ok = False
        # Sanity: RSA modulus should not be all zeros.
        if rsa_mod == b"\x00" * 128:
            print(f"FAIL: RSA modulus is all zeros")
            ok = False

        print()
        print("PASS — gateway SM_KEY handshake is well-formed" if ok
              else "FAIL — see errors above")
        return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
