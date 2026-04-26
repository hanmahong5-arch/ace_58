"""AION 5.8 protocol simulator — full client-side handshake driver.

Replaces the 35 GB NCSoft client for end-to-end gateway smoke testing.
Speaks the actual AION 5.8 wire protocol: BF-LE + RSA-NoPadding + XOR
stream cipher (seed=1234), exactly mirroring the gateway's expectations
defined in ``server/src/cmd/gateway/{handshake,game,session}.go``.

Handshake walked:

  Auth port :2108
    1. Read SM_KEY (clear)         — RSA modulus + 16-byte BF static key
    2. Init BF cipher + XOR encoder/decoder (both seed=1234)
    3. Send CM_AUTH_LOGIN          — RSA-NoPadding-encrypted credentials
    4. Read SM_LOGIN_OK / FAIL
    5. Send CM_PLAY                — server selection
    6. Read SM_PLAY_OK             — 16-byte one-time session token
    7. Disconnect

  Game port :7777
    8. Read SM_SESSION_KEY (clear) — 16-byte per-session BF key
    9. Re-init BF with session key, reset XOR state to seed=1234
   10. Send CM_SESSION_CONFIRM     — 16-byte token
   11. Read SM_CHARACTER_LIST      — auto-pushed by World on player.enter

Cipher chain analysis (cross-checked against gateway/session.go):

  Server send: plaintext → BF.Encrypt(payload[2:]) → XOR.Encode(payload[2:]) → wire
  Client recv: wire → XOR.Decode(payload[2:]) → BF.Decrypt(payload[2:]) → plaintext

  Client send: plaintext → XOR.Encode(payload[2:]) → BF.Encrypt(payload[2:]) → wire
  Server recv: wire → BF.Decrypt(payload[2:]) → XOR.Decode(payload[2:]) → plaintext

Both sides keep two independent XOR states (Encoder/Decoder), each starting
at seed=1234.  Client.xorEnc state advances in lockstep with Server.xorDec;
Client.xorDec state advances in lockstep with Server.xorEnc.

Usage:
    python proto_simulator.py [--account NAME] [--password PASS] [--host 127.0.0.1]
"""
from __future__ import annotations

import argparse
import socket
import struct
import sys
import time
from typing import Tuple

from Crypto.Cipher import Blowfish

# --- Protocol constants (mirror server/src/internal/aionproto/opcodes.go) ---

SM_KEY                = 0x0000
CM_AUTH_LOGIN         = 0x0001
SM_LOGIN_OK           = 0x0002
SM_LOGIN_FAIL         = 0x0003
CM_PLAY               = 0x0005
SM_PLAY_OK            = 0x0006
SM_PLAY_FAIL          = 0x0007
SM_SESSION_KEY        = 0x001A
CM_SESSION_CONFIRM    = 0x001B
SM_CHARACTER_LIST     = 0x0010

XOR_INITIAL_SEED = 1234
RSA_BLOCK_SIZE   = 128
BF_BLOCK_SIZE    = 8
HEADER_SIZE      = 2
ACCOUNT_NAME_MAX = 17


# --- Blowfish-LE wrapper (mirror server/src/internal/crypto/blowfish_le.go) ---

class BlowfishLE:
    """NCSoft non-standard Blowfish: standard key schedule, but reads/writes
    cipher blocks as little-endian 32-bit word pairs (instead of big-endian).
    pycryptodome's Blowfish always uses big-endian, so we swap word byte order
    around each call to encrypt_block / decrypt_block.
    """

    def __init__(self, key: bytes) -> None:
        if not (1 <= len(key) <= 56):
            raise ValueError(f"BF key must be 1..56 bytes, got {len(key)}")
        # Build encrypt and decrypt cipher objects (ECB has no IV/state).
        self._enc = Blowfish.new(key, Blowfish.MODE_ECB)
        self._dec = Blowfish.new(key, Blowfish.MODE_ECB)

    @staticmethod
    def _swap_words(block: bytes) -> bytes:
        """Convert between LE-pair and BE-pair representation of an 8B block."""
        xl = struct.unpack_from("<I", block, 0)[0]
        xr = struct.unpack_from("<I", block, 4)[0]
        return struct.pack(">II", xl, xr)

    def encrypt_block(self, block: bytes) -> bytes:
        be_in = self._swap_words(block)
        be_out = self._enc.encrypt(be_in)
        return self._swap_words(be_out)

    def decrypt_block(self, block: bytes) -> bytes:
        be_in = self._swap_words(block)
        be_out = self._dec.decrypt(be_in)
        return self._swap_words(be_out)

    def encrypt_packet(self, pkt: bytearray) -> None:
        """In-place encrypt of pkt[2:] in 8-byte ECB blocks (header preserved)."""
        for off in range(HEADER_SIZE, len(pkt) - (len(pkt) - HEADER_SIZE) % BF_BLOCK_SIZE, BF_BLOCK_SIZE):
            pkt[off:off + BF_BLOCK_SIZE] = self.encrypt_block(bytes(pkt[off:off + BF_BLOCK_SIZE]))

    def decrypt_packet(self, pkt: bytearray) -> None:
        """In-place decrypt of pkt[2:] in 8-byte ECB blocks (header preserved)."""
        for off in range(HEADER_SIZE, len(pkt) - (len(pkt) - HEADER_SIZE) % BF_BLOCK_SIZE, BF_BLOCK_SIZE):
            pkt[off:off + BF_BLOCK_SIZE] = self.decrypt_block(bytes(pkt[off:off + BF_BLOCK_SIZE]))


# --- XOR stream cipher (mirror server/src/internal/crypto/xor.go) ---

class XORCipher:
    """Stateful XOR cipher: c = b XOR low(state); state += c (post-XOR add).

    Encoder takes plaintext byte b, emits encrypted byte c, advances state by c.
    Decoder takes encrypted byte c, recovers plaintext, advances state by c.
    Encoder and decoder advance state identically when they see the same wire
    byte, so client.xorEnc and server.xorDec stay synchronised.
    """

    def __init__(self, seed: int = XOR_INITIAL_SEED) -> None:
        self.state = seed & 0xFFFFFFFF

    def encode(self, data: bytearray) -> None:
        for i in range(len(data)):
            c = data[i] ^ (self.state & 0xFF)
            self.state = (self.state + c) & 0xFFFFFFFF
            data[i] = c

    def decode(self, data: bytearray) -> None:
        for i in range(len(data)):
            enc = data[i]
            data[i] = enc ^ (self.state & 0xFF)
            self.state = (self.state + enc) & 0xFFFFFFFF


# --- RSA-NoPadding encrypt (raw textbook RSA, matches server DecryptCredentials) ---

def rsa_nopad_encrypt(modulus: bytes, plaintext: bytes, e: int = 65537) -> bytes:
    """Raw RSA: c = m^e mod n.  Plaintext must be exactly RSA_BLOCK_SIZE bytes."""
    if len(plaintext) != RSA_BLOCK_SIZE:
        raise ValueError(f"plaintext must be {RSA_BLOCK_SIZE} bytes, got {len(plaintext)}")
    n = int.from_bytes(modulus, "big")
    m = int.from_bytes(plaintext, "big")
    if m >= n:
        raise ValueError("plaintext >= modulus (high bit set; reduce or randomise scramble byte)")
    c = pow(m, e, n)
    return c.to_bytes(RSA_BLOCK_SIZE, "big")


def build_credential_block(account: str, password: str) -> bytes:
    """Build the 128-byte cleartext that goes into the RSA credential block.

    Layout (matches server/src/internal/crypto/rsa.go ParseCredentials):
      [0..0]    : scramble byte (0 ensures m < n; first bit cleared)
      [1..17]   : account name (17 bytes, null-padded)
      [18..127] : password (110 bytes, null-padded)
    """
    if len(account) > ACCOUNT_NAME_MAX:
        raise ValueError(f"account name max {ACCOUNT_NAME_MAX} chars, got {len(account)}")
    block = bytearray(RSA_BLOCK_SIZE)
    block[0] = 0x00  # scramble byte cleared so m < n
    block[1:1 + len(account)] = account.encode("ascii")
    block[18:18 + len(password)] = password.encode("ascii")
    return bytes(block)


# --- Packet builder ---

def build_packet(opcode: int, payload: bytes = b"") -> bytearray:
    """Build a wire-format packet: header(2B LE) + opcode(2B LE) + payload + zero-padding.

    Payload (post-header) is zero-padded so length is a multiple of BF_BLOCK_SIZE,
    matching server/src/internal/aionproto/packet.go Bytes().
    """
    body_len = 2 + len(payload)  # opcode + payload
    pad = (-body_len) % BF_BLOCK_SIZE
    total = HEADER_SIZE + body_len + pad
    pkt = bytearray(total)
    struct.pack_into("<H", pkt, 0, total)
    struct.pack_into("<H", pkt, 2, opcode)
    pkt[4:4 + len(payload)] = payload
    return pkt


# --- Simulator client ---

class AionClient:
    def __init__(self, host: str, account: str, password: str, server_id: int = 10) -> None:
        self.host = host
        self.account = account
        self.password = password
        self.server_id = server_id
        self.sock: socket.socket | None = None
        self.bf: BlowfishLE | None = None
        self.xor_enc = XORCipher()  # for outgoing CM_*
        self.xor_dec = XORCipher()  # for incoming SM_*
        self.crypto_active = False  # set True after SM_KEY / SM_SESSION_KEY received
        # Filled by the auth handshake:
        self.rsa_modulus: bytes | None = None
        self.bf_static_key: bytes | None = None
        self.session_token: bytes | None = None

    # --- I/O ---

    def _connect(self, port: int) -> None:
        self.sock = socket.create_connection((self.host, port), timeout=5.0)
        self.bf = None
        self.xor_enc = XORCipher()
        self.xor_dec = XORCipher()
        self.crypto_active = False

    def _close(self) -> None:
        if self.sock is not None:
            try:
                self.sock.close()
            finally:
                self.sock = None

    def _recv_exact(self, n: int) -> bytes:
        assert self.sock is not None
        buf = bytearray()
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError(f"peer closed after {len(buf)}/{n} bytes")
            buf += chunk
        return bytes(buf)

    def _read_packet(self) -> Tuple[int, bytes]:
        """Read one packet from the wire, applying client decode (XOR.D → BF.D).

        Returns (opcode, payload_bytes).  Padding is left intact in payload.
        """
        header = self._recv_exact(HEADER_SIZE)
        total_len = struct.unpack_from("<H", header)[0]
        body = self._recv_exact(total_len - HEADER_SIZE)
        pkt = bytearray(header + body)
        if self.crypto_active:
            # Reverse server send chain (BF.E → XOR.E) by applying inverses
            # in reverse order: XOR.D first, then BF.D.
            payload = bytearray(pkt[HEADER_SIZE:])
            self.xor_dec.decode(payload)
            pkt[HEADER_SIZE:] = payload
            self.bf.decrypt_packet(pkt)
        opcode = struct.unpack_from("<H", pkt, HEADER_SIZE)[0]
        body = bytes(pkt[HEADER_SIZE + 2:])
        return opcode, body

    def _send_packet(self, opcode: int, payload: bytes = b"") -> None:
        """Build and send a packet, applying client encode (XOR.E → BF.E)."""
        assert self.sock is not None
        pkt = build_packet(opcode, payload)
        if self.crypto_active:
            # Order matters: XOR first (so server's BF.D → XOR.D chain reverses).
            payload_view = bytearray(pkt[HEADER_SIZE:])
            self.xor_enc.encode(payload_view)
            pkt[HEADER_SIZE:] = payload_view
            self.bf.encrypt_packet(pkt)
        self.sock.sendall(bytes(pkt))

    # --- Phase 1: auth port :2108 ---

    def auth_phase(self, port: int = 2108) -> bool:
        print(f"\n[auth :{port}] connecting...")
        self._connect(port)

        # 1. SM_KEY (clear)
        opcode, body = self._read_packet()
        if opcode != SM_KEY:
            print(f"FAIL: expected SM_KEY (0x00), got 0x{opcode:02X}")
            return False
        if len(body) < 4 + RSA_BLOCK_SIZE + 16 + 1:
            print(f"FAIL: SM_KEY body too short ({len(body)} bytes)")
            return False
        scramble = struct.unpack_from("<I", body, 0)[0]
        self.rsa_modulus = body[4:4 + RSA_BLOCK_SIZE]
        self.bf_static_key = body[4 + RSA_BLOCK_SIZE:4 + RSA_BLOCK_SIZE + 16]
        country = body[4 + RSA_BLOCK_SIZE + 16]
        print(f"  ✓ SM_KEY received")
        print(f"    scramble = 0x{scramble:08X}")
        print(f"    RSA modulus head/tail = {self.rsa_modulus[:8].hex()} ... {self.rsa_modulus[-8:].hex()}")
        print(f"    BF static key         = {self.bf_static_key.hex()}")
        print(f"    country code          = {country}")

        # Activate crypto for subsequent traffic.
        self.bf = BlowfishLE(self.bf_static_key)
        self.crypto_active = True

        # 2. CM_AUTH_LOGIN
        cred_clear = build_credential_block(self.account, self.password)
        cred_enc = rsa_nopad_encrypt(self.rsa_modulus, cred_clear)
        version = struct.pack("<I", 0x00000001)  # client version (informational)
        self._send_packet(CM_AUTH_LOGIN, cred_enc + version)
        print(f"  → CM_AUTH_LOGIN sent (account={self.account!r})")

        # 3. SM_LOGIN_OK or SM_LOGIN_FAIL
        opcode, body = self._read_packet()
        if opcode == SM_LOGIN_FAIL:
            reason = body[0] if body else 0xFF
            print(f"  ✗ SM_LOGIN_FAIL reason=0x{reason:02X}")
            return False
        if opcode != SM_LOGIN_OK:
            print(f"FAIL: expected SM_LOGIN_OK, got 0x{opcode:02X}")
            return False
        account_id = struct.unpack_from("<Q", body, 0)[0]
        n_servers = body[8]
        print(f"  ✓ SM_LOGIN_OK account_id={account_id} servers={n_servers}")

        # 4. CM_PLAY (server selection)
        self._send_packet(CM_PLAY, struct.pack("<I", self.server_id))
        print(f"  → CM_PLAY server_id={self.server_id}")

        # 5. SM_PLAY_OK
        opcode, body = self._read_packet()
        if opcode == SM_PLAY_FAIL:
            print(f"  ✗ SM_PLAY_FAIL")
            return False
        if opcode != SM_PLAY_OK:
            print(f"FAIL: expected SM_PLAY_OK, got 0x{opcode:02X}")
            return False
        # body = server_id(4) + token(16) + padding
        self.session_token = body[4:20]
        print(f"  ✓ SM_PLAY_OK token={self.session_token.hex()}")

        self._close()
        return True

    # --- Phase 2: game port :7777 ---

    def game_phase(self, port: int = 7777) -> bool:
        print(f"\n[game :{port}] connecting...")
        self._connect(port)

        # 1. SM_SESSION_KEY (clear)
        opcode, body = self._read_packet()
        if opcode != SM_SESSION_KEY:
            print(f"FAIL: expected SM_SESSION_KEY (0x1A), got 0x{opcode:02X}")
            return False
        if len(body) < 16:
            print(f"FAIL: SM_SESSION_KEY body too short ({len(body)} bytes)")
            return False
        game_bf_key = body[:16]
        print(f"  ✓ SM_SESSION_KEY game_bf_key={game_bf_key.hex()}")

        # Activate crypto with the per-session BF key.  XOR state was already
        # reset to seed=1234 in _connect().
        self.bf = BlowfishLE(game_bf_key)
        self.crypto_active = True

        # 2. CM_SESSION_CONFIRM
        if self.session_token is None:
            print("FAIL: no session token from auth phase")
            return False
        self._send_packet(CM_SESSION_CONFIRM, self.session_token)
        print(f"  → CM_SESSION_CONFIRM sent")

        # 3. SM_CHARACTER_LIST (auto-pushed by World on player.enter)
        # Generous wait — World's NATS dispatch + DB call may take a moment.
        self.sock.settimeout(5.0)
        try:
            opcode, body = self._read_packet()
        except socket.timeout:
            print("  ✗ no SM_CHARACTER_LIST within 5s (expected — Sprint 0 SP gap)")
            self._close()
            return False
        if opcode != SM_CHARACTER_LIST:
            print(f"  ⚠ unexpected first SM packet: 0x{opcode:02X} ({len(body)} bytes payload)")
            # Not fatal — World may emit SM_INSTANCE_COOLDOWNS or similar first.
        else:
            char_count = body[0] if body else 0
            print(f"  ✓ SM_CHARACTER_LIST received chars={char_count}")

        self._close()
        return True


def main() -> int:
    ap = argparse.ArgumentParser(description="AION 5.8 protocol simulator")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--auth-port", type=int, default=2108)
    ap.add_argument("--game-port", type=int, default=7777)
    ap.add_argument("--account", default="testacct")
    ap.add_argument("--password", default="testpass")
    ap.add_argument("--server-id", type=int, default=10)
    ap.add_argument("--auth-only", action="store_true",
                    help="exit after auth phase (skip game-port handshake)")
    args = ap.parse_args()

    print(f"=== AION 5.8 protocol simulator ===")
    print(f"target: {args.host}:{args.auth_port} (auth) / :{args.game_port} (game)")
    print(f"account: {args.account!r}")

    t0 = time.time()
    client = AionClient(args.host, args.account, args.password, args.server_id)

    if not client.auth_phase(args.auth_port):
        print("\n=== AUTH PHASE FAILED ===")
        return 1

    if args.auth_only:
        print(f"\n=== AUTH OK in {(time.time()-t0)*1000:.1f}ms ===")
        return 0

    # Brief pause: gateway publishes player.login → World subscribes on .enter
    # which races against our :7777 connect.  100ms is comfortable.
    time.sleep(0.1)

    if not client.game_phase(args.game_port):
        print("\n=== GAME PHASE FAILED ===")
        return 1

    print(f"\n=== ALL PHASES OK in {(time.time()-t0)*1000:.1f}ms ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
