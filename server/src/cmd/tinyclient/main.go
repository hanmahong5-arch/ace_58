// Package main 实现 AION 5.8 协议的 Go 版极小客户端 (tinyclient)。
//
// 用途：作为 5 进程拓扑端到端 boot-test 的最小验证客户端。
// 它复用了主项目 internal/crypto + internal/aionproto，与服务端使用完全一致的
// BF-LE / RSA-NoPad / XOR(seed=1234) 实现，避免任何"我以为对"但实际错位的协议
// 漂移问题（参考 bin/proto_simulator.py 的 Python 实现作为交叉对照）。
//
// 流程：
//
//	auth :2108
//	  ← SM_KEY (clear, 含 RSA modulus + BF static key)
//	  → CM_AUTH_LOGIN (RSA-NoPad 加密的 17B account + 110B password)
//	  ← SM_LOGIN_OK / SM_LOGIN_FAIL
//	  → CM_PLAY (server_id)
//	  ← SM_PLAY_OK (16B 一次性 token)
//	  断开
//
//	game :7777
//	  ← SM_SESSION_KEY (clear, 16B 会话 BF key)
//	  → CM_SESSION_CONFIRM (token)
//	  ← SM_CHARACTER_LIST (World 通过 NATS player.enter 触发后异步推送)
//
// 退出码：0 = 端到端成功；1 = 任何阶段失败。
package main

import (
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"math/big"
	"net"
	"os"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
)

// 与 internal/aionproto 保持一致的常量（仅本工具内部使用，不导出）。
const (
	rsaBlockSize     = crypto.CredentialBlockSize  // 128
	accountNameMax   = crypto.AccountNameMaxLen    // 17
	passwordOffset   = 18                          // RSA block 内 password 起始偏移
	passwordMaxLen   = rsaBlockSize - passwordOffset
	defaultAuthPort  = 2108
	defaultGamePort  = 7777
	defaultServerID  = uint32(10)
	rsaPublicExp     = 65537                        // 与 NCSoft 真端一致
	connectTimeout   = 5 * time.Second
	postLoginPause   = 100 * time.Millisecond       // 给 NATS player.login → World 一点时间
	smCharListWindow = 5 * time.Second              // World 推 SM_CHARACTER_LIST 的最长等待
)

// tinyClient 维护一次完整握手过程中的所有可变状态。
type tinyClient struct {
	host       string
	account    string
	password   string
	serverID   uint32
	logger     *slog.Logger

	conn    net.Conn
	bf      *crypto.BlowfishLE
	xorEnc  *crypto.XORCipher // 客户端 → 服务端方向
	xorDec  *crypto.XORCipher // 服务端 → 客户端方向
	encOn   bool              // 是否已激活 BF + XOR

	// 由 auth_phase 填充，供 game_phase 使用
	rsaModulus   []byte
	bfStaticKey  []byte
	sessionToken []byte
}

func main() {
	host := flag.String("host", "127.0.0.1", "gateway host")
	authPort := flag.Int("auth-port", defaultAuthPort, "gateway auth port")
	gamePort := flag.Int("game-port", defaultGamePort, "gateway game port")
	account := flag.String("account", "shiguang", "account name (<=17 chars)")
	password := flag.String("password", "hunter2", "account password")
	serverID := flag.Uint("server-id", uint(defaultServerID), "logical server selection")
	authOnly := flag.Bool("auth-only", false, "exit after auth phase")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	c := &tinyClient{
		host:     *host,
		account:  *account,
		password: *password,
		serverID: uint32(*serverID),
		logger:   logger,
	}

	t0 := time.Now()
	logger.Info("tinyclient: start", "host", *host, "account", *account)

	if err := c.authPhase(*authPort); err != nil {
		logger.Error("tinyclient: auth phase failed", "err", err)
		os.Exit(1)
	}
	logger.Info("tinyclient: auth phase OK", "elapsed", time.Since(t0))

	if *authOnly {
		os.Exit(0)
	}

	// 给 gateway → NATS → world 一点缓冲，避免 :7777 连上时 World 还没收到 player.login。
	time.Sleep(postLoginPause)

	if err := c.gamePhase(*gamePort); err != nil {
		logger.Error("tinyclient: game phase failed", "err", err)
		os.Exit(1)
	}
	logger.Info("tinyclient: end-to-end OK", "elapsed", time.Since(t0))
}

// authPhase 走完 auth :2108 端口的完整握手。
func (c *tinyClient) authPhase(port int) error {
	if err := c.connect(port); err != nil {
		return fmt.Errorf("connect auth: %w", err)
	}
	defer c.close()

	// 1. SM_KEY (clear)
	opcode, body, err := c.readPacket()
	if err != nil {
		return fmt.Errorf("read SM_KEY: %w", err)
	}
	if opcode != aionproto.SM_KEY {
		return fmt.Errorf("expected SM_KEY (0x%02X), got 0x%02X", aionproto.SM_KEY, opcode)
	}
	// SM_KEY layout: scramble(4) + RSA modulus(128) + BF key(16) + country(1) + ...
	if len(body) < 4+rsaBlockSize+16+1 {
		return fmt.Errorf("SM_KEY body too short: %d bytes", len(body))
	}
	c.rsaModulus = append([]byte(nil), body[4:4+rsaBlockSize]...)
	c.bfStaticKey = append([]byte(nil), body[4+rsaBlockSize:4+rsaBlockSize+16]...)
	c.logger.Info("tinyclient: SM_KEY received",
		"bf_key", fmt.Sprintf("%x", c.bfStaticKey),
		"country", body[4+rsaBlockSize+16])

	// 启用加密：之后所有 read/write 都走 BF-LE + XOR(seed=1234) 链路。
	if err := c.activateCrypto(c.bfStaticKey); err != nil {
		return fmt.Errorf("activate crypto: %w", err)
	}

	// 2. CM_AUTH_LOGIN
	cred, err := c.encryptCredentials()
	if err != nil {
		return fmt.Errorf("encrypt credentials: %w", err)
	}
	// AION client 在凭据后追加一个 4 字节的客户端版本号；服务端目前不强校验。
	versionTail := []byte{0x01, 0x00, 0x00, 0x00}
	if err := c.sendPacket(aionproto.CM_AUTH_LOGIN, append(cred, versionTail...)); err != nil {
		return fmt.Errorf("send CM_AUTH_LOGIN: %w", err)
	}
	c.logger.Info("tinyclient: CM_AUTH_LOGIN sent", "account", c.account)

	// 3. SM_LOGIN_OK / SM_LOGIN_FAIL
	opcode, body, err = c.readPacket()
	if err != nil {
		return fmt.Errorf("read SM_LOGIN result: %w", err)
	}
	switch opcode {
	case aionproto.SM_LOGIN_FAIL:
		var reason byte
		if len(body) > 0 {
			reason = body[0]
		}
		return fmt.Errorf("SM_LOGIN_FAIL reason=0x%02X", reason)
	case aionproto.SM_LOGIN_OK:
		// body 起始处是 8 字节 account_id（NCSoft 用 uint64，但实际数值在 int32 内）
		if len(body) < 9 {
			return fmt.Errorf("SM_LOGIN_OK body too short: %d", len(body))
		}
		accountID := binary.LittleEndian.Uint64(body[0:8])
		c.logger.Info("tinyclient: SM_LOGIN_OK", "account_id", accountID, "servers", body[8])
	default:
		return fmt.Errorf("unexpected opcode after CM_AUTH_LOGIN: 0x%02X", opcode)
	}

	// 4. CM_PLAY (4 字节 server_id)
	playPayload := make([]byte, 4)
	binary.LittleEndian.PutUint32(playPayload, c.serverID)
	if err := c.sendPacket(aionproto.CM_PLAY, playPayload); err != nil {
		return fmt.Errorf("send CM_PLAY: %w", err)
	}

	// 5. SM_PLAY_OK / SM_PLAY_FAIL
	opcode, body, err = c.readPacket()
	if err != nil {
		return fmt.Errorf("read SM_PLAY result: %w", err)
	}
	switch opcode {
	case aionproto.SM_PLAY_FAIL:
		return fmt.Errorf("SM_PLAY_FAIL")
	case aionproto.SM_PLAY_OK:
		// SM_PLAY_OK = server_id(4) + token(16) + 填充
		if len(body) < 20 {
			return fmt.Errorf("SM_PLAY_OK body too short: %d", len(body))
		}
		c.sessionToken = append([]byte(nil), body[4:20]...)
		c.logger.Info("tinyclient: SM_PLAY_OK", "token", fmt.Sprintf("%x", c.sessionToken))
	default:
		return fmt.Errorf("unexpected opcode after CM_PLAY: 0x%02X", opcode)
	}

	return nil
}

// gamePhase 走完 game :7777 端口的握手并等待 World 推送 SM_CHARACTER_LIST。
func (c *tinyClient) gamePhase(port int) error {
	if err := c.connect(port); err != nil {
		return fmt.Errorf("connect game: %w", err)
	}
	defer c.close()

	// 1. SM_SESSION_KEY (clear)
	opcode, body, err := c.readPacket()
	if err != nil {
		return fmt.Errorf("read SM_SESSION_KEY: %w", err)
	}
	if opcode != aionproto.SM_SESSION_KEY {
		return fmt.Errorf("expected SM_SESSION_KEY (0x%02X), got 0x%02X", aionproto.SM_SESSION_KEY, opcode)
	}
	if len(body) < 16 {
		return fmt.Errorf("SM_SESSION_KEY body too short: %d", len(body))
	}
	gameBFKey := body[:16]
	c.logger.Info("tinyclient: SM_SESSION_KEY received", "key", fmt.Sprintf("%x", gameBFKey))

	// 用会话 BF key 重置加密状态（XOR seed 重新回到 1234）。
	if err := c.activateCrypto(gameBFKey); err != nil {
		return fmt.Errorf("re-activate crypto with game key: %w", err)
	}

	// 2. CM_SESSION_CONFIRM (16B token)
	if c.sessionToken == nil {
		return fmt.Errorf("no session token from auth phase")
	}
	if err := c.sendPacket(aionproto.CM_SESSION_CONFIRM, c.sessionToken); err != nil {
		return fmt.Errorf("send CM_SESSION_CONFIRM: %w", err)
	}
	c.logger.Info("tinyclient: CM_SESSION_CONFIRM sent")

	// 3. 等 World 通过 NATS subject world.sm.{seq_id} 推 SM_CHARACTER_LIST。
	//    Sprint 0 阶段 SP 未必接通，所以即使收到非 SM_CHARACTER_LIST 也算端到端 NATS 通了。
	if err := c.conn.SetReadDeadline(time.Now().Add(smCharListWindow)); err != nil {
		return fmt.Errorf("set read deadline: %w", err)
	}
	opcode, body, err = c.readPacket()
	if err != nil {
		return fmt.Errorf("await first SM after CM_SESSION_CONFIRM: %w", err)
	}
	if opcode == aionproto.SM_CHARACTER_LIST {
		var chars byte
		if len(body) > 0 {
			chars = body[0]
		}
		c.logger.Info("tinyclient: SM_CHARACTER_LIST received", "chars", chars)
	} else {
		c.logger.Warn("tinyclient: first SM after CM_SESSION_CONFIRM was not SM_CHARACTER_LIST",
			"opcode", fmt.Sprintf("0x%02X", opcode), "payload_len", len(body))
	}

	return nil
}

// --- 底层 I/O + 加密辅助函数 ---

// connect 建 TCP 连接并把加密状态彻底重置（每个端口独立握手）。
func (c *tinyClient) connect(port int) error {
	d := net.Dialer{Timeout: connectTimeout}
	// 用 net.JoinHostPort 而非裸 fmt.Sprintf — 兼容 IPv6 字面量（如 ::1）。
	conn, err := d.Dial("tcp", net.JoinHostPort(c.host, fmt.Sprintf("%d", port)))
	if err != nil {
		return err
	}
	c.conn = conn
	c.bf = nil
	c.xorEnc = crypto.NewXORCipher()
	c.xorDec = crypto.NewXORCipher()
	c.encOn = false
	return nil
}

func (c *tinyClient) close() {
	if c.conn != nil {
		_ = c.conn.Close()
		c.conn = nil
	}
}

// activateCrypto 切换到加密模式：用给定 BF key 初始化新的 BlowfishLE，
// 并将两路 XOR cipher 重置为初始 seed (1234)。
func (c *tinyClient) activateCrypto(bfKey []byte) error {
	bf, err := crypto.NewBlowfishLE(bfKey)
	if err != nil {
		return err
	}
	c.bf = bf
	c.xorEnc = crypto.NewXORCipher()
	c.xorDec = crypto.NewXORCipher()
	c.encOn = true
	return nil
}

// readPacket 读取一个完整 AION 数据包，必要时反向应用加密链路。
//
// 服务端发送链：plaintext → BF.E → XOR.E → wire
// 客户端接收链：wire → XOR.D → BF.D → plaintext
func (c *tinyClient) readPacket() (uint16, []byte, error) {
	header := make([]byte, aionproto.HeaderSize)
	if _, err := io.ReadFull(c.conn, header); err != nil {
		return 0, nil, fmt.Errorf("read header: %w", err)
	}
	totalLen := binary.LittleEndian.Uint16(header)
	if int(totalLen) < aionproto.MinPacketSize {
		return 0, nil, fmt.Errorf("packet length %d below min %d", totalLen, aionproto.MinPacketSize)
	}
	body := make([]byte, int(totalLen)-aionproto.HeaderSize)
	if _, err := io.ReadFull(c.conn, body); err != nil {
		return 0, nil, fmt.Errorf("read body: %w", err)
	}

	if c.encOn {
		// 1) XOR 解码（先解 XOR，因为服务端最后一步是 XOR.E）
		c.xorDec.Decode(body)
		// 2) BF-LE 块解密（每 8 字节一块）
		c.decryptBody(body)
	}

	if len(body) < 2 {
		return 0, nil, fmt.Errorf("decrypted body too short for opcode: %d", len(body))
	}
	opcode := binary.LittleEndian.Uint16(body[:2])
	return opcode, body[2:], nil
}

// sendPacket 构造并发送一个 AION 数据包，必要时正向应用加密链路。
//
// 客户端发送链：plaintext → XOR.E → BF.E → wire
// 服务端接收链：wire → BF.D → XOR.D → plaintext
func (c *tinyClient) sendPacket(opcode uint16, payload []byte) error {
	bodyLen := 2 + len(payload) // opcode + payload
	pad := (-bodyLen) & (aionproto.BlockSize - 1)
	totalLen := aionproto.HeaderSize + bodyLen + pad

	pkt := make([]byte, totalLen)
	binary.LittleEndian.PutUint16(pkt[0:], uint16(totalLen))
	binary.LittleEndian.PutUint16(pkt[aionproto.HeaderSize:], opcode)
	copy(pkt[aionproto.HeaderSize+2:], payload)

	if c.encOn {
		body := pkt[aionproto.HeaderSize:]
		// 1) XOR 编码（先 XOR，再 BF；与服务端解码顺序对称）
		c.xorEnc.Encode(body)
		// 2) BF-LE 块加密
		c.encryptBody(body)
	}

	_, err := c.conn.Write(pkt)
	return err
}

// encryptBody 对 body 中的每个 8 字节块就地 BF-LE 加密。
func (c *tinyClient) encryptBody(body []byte) {
	for off := 0; off+aionproto.BlockSize <= len(body); off += aionproto.BlockSize {
		c.bf.EncryptBlock(body[off:off+aionproto.BlockSize], body[off:off+aionproto.BlockSize])
	}
}

// decryptBody 对 body 中的每个 8 字节块就地 BF-LE 解密。
func (c *tinyClient) decryptBody(body []byte) {
	for off := 0; off+aionproto.BlockSize <= len(body); off += aionproto.BlockSize {
		c.bf.DecryptBlock(body[off:off+aionproto.BlockSize], body[off:off+aionproto.BlockSize])
	}
}

// encryptCredentials 构造 RSA-NoPad 加密的 128 字节凭据块。
//
// 明文 layout (与 server/internal/crypto/rsa.go ParseCredentials 对称)：
//
//	[0]      scramble byte = 0x00 （确保 m < n）
//	[1..17]  account name (17 bytes, null padded)
//	[18..127] password (110 bytes, null padded)
//
// 加密：c = m^e mod n  （RSA-NoPad，textbook RSA）
func (c *tinyClient) encryptCredentials() ([]byte, error) {
	if len(c.account) > accountNameMax {
		return nil, fmt.Errorf("account name too long: %d > %d", len(c.account), accountNameMax)
	}
	if len(c.password) > passwordMaxLen {
		return nil, fmt.Errorf("password too long: %d > %d", len(c.password), passwordMaxLen)
	}

	plain := make([]byte, rsaBlockSize)
	plain[0] = 0x00 // scramble byte cleared
	copy(plain[1:], c.account)
	copy(plain[passwordOffset:], c.password)

	// RSA-NoPad: c = m^e mod n。modulus 由 SM_KEY 提供（big-endian）。
	n := new(big.Int).SetBytes(c.rsaModulus)
	m := new(big.Int).SetBytes(plain)
	if m.Cmp(n) >= 0 {
		return nil, fmt.Errorf("plaintext >= modulus (m bit too high; check scramble byte)")
	}
	e := big.NewInt(int64(rsaPublicExp))
	cInt := new(big.Int).Exp(m, e, n)

	// 输出固定 128 字节（不足前面补 0），与 NCSoft 客户端行为一致。
	cipherBytes := cInt.Bytes()
	if len(cipherBytes) > rsaBlockSize {
		return nil, fmt.Errorf("ciphertext > block size: %d", len(cipherBytes))
	}
	out := make([]byte, rsaBlockSize)
	copy(out[rsaBlockSize-len(cipherBytes):], cipherBytes)
	return out, nil
}
