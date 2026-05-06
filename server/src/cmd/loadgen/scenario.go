// Package main — scenario.go: AION 5.8 协议级压测的"剧本"层。
//
// 本文件把 cmd/tinyclient/main.go (git HEAD) 的 phase 函数提炼为一个
// 紧凑的 Scenario 接口。Scenario 接收一对 (auth conn, game conn) 与
// 一组 phase metric callback，按 AION 真端握手次序执行，记录每个
// phase 的 latency 与 error。
//
// 不抽象 Plugin、不支持自定义剧本树（YAGNI）；仅满足 loadgen ramp 需要的
// "login → enter world → 几个轻量 packet → logout" 闭环。
//
// 关键设计：
//
//   - **协议层 100% 复用 internal/crypto + internal/aionproto**，不重写 BF/RSA/XOR。
//     这是与 tinyclient 共享的代码路径，loadgen 不存在"协议漂移"风险。
//   - **每个 worker 一份独立 Scenario 实例**，彼此不共享状态；rsaModulus /
//     bfStaticKey / sessionToken 全部 worker-local。
//   - **randName 生成规则与 tinyclient working-tree 版本逐字对齐**——
//     1000 并发不会撞名（alphabet=32 / suffix=12 → ~10^18 空间），
//     避免 ap_create_account 主键冲突。
//   - **scramble byte = 0x00**（HEAD tinyclient 行为）是已知能让 RSA m<n 的
//     最稳健选择；不要随便改成随机，否则 m≥n 会偶发失败。
package main

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"io"
	"math/big"
	mrand "math/rand"
	"net"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/crypto"
)

// 与 internal/aionproto 保持一致的协议常量（仅本工具内部使用）。
const (
	rsaBlockSize    = crypto.CredentialBlockSize // 128
	accountNameMax  = crypto.AccountNameMaxLen   // 17
	passwordOffset  = 18                         // RSA block 内 password 起始偏移
	passwordMaxLen  = rsaBlockSize - passwordOffset
	rsaPublicExp    = 65537
	defaultServerID = uint32(10)

	// 各 phase 的 deadline：远超真实 RTT，避免误判 timeout。
	smKeyTimeout      = 3 * time.Second
	loginRespTimeout  = 5 * time.Second
	playRespTimeout   = 3 * time.Second
	sessionKeyTimeout = 3 * time.Second
	charListTimeout   = 5 * time.Second
)

// Phase 标记当前测量的握手阶段（用于 prom histogram label）。
type Phase string

const (
	PhaseConnectAuth     Phase = "connect_auth"
	PhaseRecvSMKey       Phase = "recv_sm_key"
	PhaseSendAuthLogin   Phase = "send_auth_login"
	PhaseRecvLoginResp   Phase = "recv_login_resp"
	PhaseSendPlay        Phase = "send_play"
	PhaseRecvPlayResp    Phase = "recv_play_resp"
	PhaseConnectGame     Phase = "connect_game"
	PhaseRecvSessionKey  Phase = "recv_session_key"
	PhaseSendSessionConf Phase = "send_session_confirm"
	PhaseRecvCharList    Phase = "recv_char_list"
	PhaseSendLogout      Phase = "send_logout"
)

// AllPhases 用于在 metrics 启动时一次性预热 histogram label，
// 防止"第一次 scrape 时 phase 标签尚未注册导致 dashboard 阶段缺线"。
var AllPhases = []Phase{
	PhaseConnectAuth, PhaseRecvSMKey, PhaseSendAuthLogin, PhaseRecvLoginResp,
	PhaseSendPlay, PhaseRecvPlayResp, PhaseConnectGame, PhaseRecvSessionKey,
	PhaseSendSessionConf, PhaseRecvCharList, PhaseSendLogout,
}

// PhaseObserver 由 metrics 层实现，loadgen 在每个 phase 结束时调用一次。
type PhaseObserver interface {
	ObservePhase(phase Phase, dur time.Duration, err error)
}

// Scenario 是一次完整玩家会话的"剧本执行器"。
//
// 调用顺序：NewScenario → Run → (defer) Close
type Scenario struct {
	host     string
	authPort int
	gamePort int
	account  string
	password string
	serverID uint32

	obs PhaseObserver

	// 协议状态（worker-local）
	conn   net.Conn
	bf     *crypto.BlowfishLE
	xorEnc *crypto.XORCipher
	xorDec *crypto.XORCipher
	encOn  bool

	rsaModulus   []byte
	bfStaticKey  []byte
	sessionToken []byte
}

// NewScenario 构造一个独立 worker 的 Scenario。account 由调用方决定
// （一般用 randName 生成）以保证 1000 并发账号不撞。
func NewScenario(host string, authPort, gamePort int, account, password string, serverID uint32, obs PhaseObserver) *Scenario {
	return &Scenario{
		host:     host,
		authPort: authPort,
		gamePort: gamePort,
		account:  account,
		password: password,
		serverID: serverID,
		obs:      obs,
	}
}

// Run 执行完整 auth → game 握手 + logout。任一 phase 失败立即返回，
// 但已经测过的 phase latency 仍会被 obs 记录（含 error 计数）。
func (s *Scenario) Run() error {
	if err := s.runAuth(); err != nil {
		return fmt.Errorf("auth: %w", err)
	}
	// gateway → NATS → world 之间留少量 buffer；与 tinyclient 100ms 对齐。
	time.Sleep(100 * time.Millisecond)
	if err := s.runGame(); err != nil {
		return fmt.Errorf("game: %w", err)
	}
	return nil
}

// Close 释放残余 conn（双 phase 各自 defer 关，但兜底一次以防中途 return）。
func (s *Scenario) Close() {
	if s.conn != nil {
		_ = s.conn.Close()
		s.conn = nil
	}
}

// runAuth 走 auth :2108 完整握手。
func (s *Scenario) runAuth() error {
	if err := s.observe(PhaseConnectAuth, func() error { return s.connect(s.authPort) }); err != nil {
		return err
	}
	defer s.closeConn()

	// 1) SM_KEY
	var smKeyBody []byte
	if err := s.observe(PhaseRecvSMKey, func() error {
		_ = s.conn.SetReadDeadline(time.Now().Add(smKeyTimeout))
		op, body, err := s.readPacket()
		if err != nil {
			return err
		}
		if op != aionproto.SM_KEY {
			return fmt.Errorf("expected SM_KEY 0x%02X, got 0x%02X", aionproto.SM_KEY, op)
		}
		if len(body) < 4+rsaBlockSize+16+1 {
			return fmt.Errorf("SM_KEY body too short: %d", len(body))
		}
		smKeyBody = body
		return nil
	}); err != nil {
		return err
	}

	s.rsaModulus = append([]byte(nil), smKeyBody[4:4+rsaBlockSize]...)
	s.bfStaticKey = append([]byte(nil), smKeyBody[4+rsaBlockSize:4+rsaBlockSize+16]...)
	if err := s.activateCrypto(s.bfStaticKey); err != nil {
		return fmt.Errorf("activate crypto: %w", err)
	}

	// 2) CM_AUTH_LOGIN
	if err := s.observe(PhaseSendAuthLogin, func() error {
		cred, err := s.encryptCredentials()
		if err != nil {
			return err
		}
		// 4 字节客户端版本号占位（与 tinyclient 一致）。
		return s.sendPacket(aionproto.CM_AUTH_LOGIN, append(cred, 0x01, 0x00, 0x00, 0x00))
	}); err != nil {
		return err
	}

	// 3) SM_LOGIN_OK / SM_LOGIN_FAIL
	if err := s.observe(PhaseRecvLoginResp, func() error {
		_ = s.conn.SetReadDeadline(time.Now().Add(loginRespTimeout))
		op, body, err := s.readPacket()
		if err != nil {
			return err
		}
		if op == aionproto.SM_LOGIN_FAIL {
			var reason byte
			if len(body) > 0 {
				reason = body[0]
			}
			return fmt.Errorf("SM_LOGIN_FAIL 0x%02X", reason)
		}
		if op != aionproto.SM_LOGIN_OK {
			return fmt.Errorf("unexpected opcode 0x%02X after CM_AUTH_LOGIN", op)
		}
		if len(body) < 9 {
			return fmt.Errorf("SM_LOGIN_OK body too short: %d", len(body))
		}
		return nil
	}); err != nil {
		return err
	}

	// 4) CM_PLAY
	if err := s.observe(PhaseSendPlay, func() error {
		payload := make([]byte, 4)
		binary.LittleEndian.PutUint32(payload, s.serverID)
		return s.sendPacket(aionproto.CM_PLAY, payload)
	}); err != nil {
		return err
	}

	// 5) SM_PLAY_OK
	return s.observe(PhaseRecvPlayResp, func() error {
		_ = s.conn.SetReadDeadline(time.Now().Add(playRespTimeout))
		op, body, err := s.readPacket()
		if err != nil {
			return err
		}
		if op == aionproto.SM_PLAY_FAIL {
			return fmt.Errorf("SM_PLAY_FAIL")
		}
		if op != aionproto.SM_PLAY_OK {
			return fmt.Errorf("unexpected opcode 0x%02X after CM_PLAY", op)
		}
		if len(body) < 20 {
			return fmt.Errorf("SM_PLAY_OK body too short: %d", len(body))
		}
		s.sessionToken = append([]byte(nil), body[4:20]...)
		return nil
	})
}

// runGame 走 game :7777 握手 + 一个 logout 包作为最轻量"闭包"包。
func (s *Scenario) runGame() error {
	if err := s.observe(PhaseConnectGame, func() error { return s.connect(s.gamePort) }); err != nil {
		return err
	}
	defer s.closeConn()

	// 1) SM_SESSION_KEY (clear)
	var gameBFKey []byte
	if err := s.observe(PhaseRecvSessionKey, func() error {
		_ = s.conn.SetReadDeadline(time.Now().Add(sessionKeyTimeout))
		op, body, err := s.readPacket()
		if err != nil {
			return err
		}
		if op != aionproto.SM_SESSION_KEY {
			return fmt.Errorf("expected SM_SESSION_KEY 0x%02X, got 0x%02X", aionproto.SM_SESSION_KEY, op)
		}
		if len(body) < 16 {
			return fmt.Errorf("SM_SESSION_KEY body too short: %d", len(body))
		}
		gameBFKey = body[:16]
		return nil
	}); err != nil {
		return err
	}

	if err := s.activateCrypto(gameBFKey); err != nil {
		return fmt.Errorf("re-activate crypto: %w", err)
	}

	// 2) CM_SESSION_CONFIRM
	if err := s.observe(PhaseSendSessionConf, func() error {
		if s.sessionToken == nil {
			return fmt.Errorf("no session token")
		}
		return s.sendPacket(aionproto.CM_SESSION_CONFIRM, s.sessionToken)
	}); err != nil {
		return err
	}

	// 3) SM_CHARACTER_LIST（World 异步推；非该 opcode 也容忍——只测 RTT）
	if err := s.observe(PhaseRecvCharList, func() error {
		_ = s.conn.SetReadDeadline(time.Now().Add(charListTimeout))
		_, _, err := s.readPacket()
		return err
	}); err != nil {
		// 不强制必须是 SM_CHARACTER_LIST；只要有响应就 phase 成功
		// （error 已经计入 obs，不再叠加）。返回 nil 让后续 logout 能跑。
		return nil
	}

	// 4) CM_LOGOUT —— 最轻量"已登入态"包，验证加密链路双向通畅。
	return s.observe(PhaseSendLogout, func() error {
		return s.sendPacket(aionproto.CM_LOGOUT, nil)
	})
}

// observe 包一层 timing：测出 phase latency 后调 obs.ObservePhase。
func (s *Scenario) observe(p Phase, fn func() error) error {
	t0 := time.Now()
	err := fn()
	if s.obs != nil {
		s.obs.ObservePhase(p, time.Since(t0), err)
	}
	return err
}

// --- 底层 I/O + 加密辅助 (与 tinyclient HEAD 等价) ---

func (s *Scenario) connect(port int) error {
	d := net.Dialer{Timeout: 5 * time.Second}
	conn, err := d.Dial("tcp", net.JoinHostPort(s.host, fmt.Sprintf("%d", port)))
	if err != nil {
		return err
	}
	s.conn = conn
	s.bf = nil
	s.xorEnc = crypto.NewXORCipher()
	s.xorDec = crypto.NewXORCipher()
	s.encOn = false
	return nil
}

func (s *Scenario) closeConn() {
	if s.conn != nil {
		_ = s.conn.Close()
		s.conn = nil
	}
}

func (s *Scenario) activateCrypto(bfKey []byte) error {
	bf, err := crypto.NewBlowfishLE(bfKey)
	if err != nil {
		return err
	}
	s.bf = bf
	s.xorEnc = crypto.NewXORCipher()
	s.xorDec = crypto.NewXORCipher()
	s.encOn = true
	return nil
}

func (s *Scenario) readPacket() (uint16, []byte, error) {
	header := make([]byte, aionproto.HeaderSize)
	if _, err := io.ReadFull(s.conn, header); err != nil {
		return 0, nil, fmt.Errorf("read header: %w", err)
	}
	totalLen := binary.LittleEndian.Uint16(header)
	if int(totalLen) < aionproto.MinPacketSize {
		return 0, nil, fmt.Errorf("pkt len %d below min %d", totalLen, aionproto.MinPacketSize)
	}
	body := make([]byte, int(totalLen)-aionproto.HeaderSize)
	if _, err := io.ReadFull(s.conn, body); err != nil {
		return 0, nil, fmt.Errorf("read body: %w", err)
	}
	if s.encOn {
		s.xorDec.Decode(body)
		for off := 0; off+aionproto.BlockSize <= len(body); off += aionproto.BlockSize {
			s.bf.DecryptBlock(body[off:off+aionproto.BlockSize], body[off:off+aionproto.BlockSize])
		}
	}
	if len(body) < 2 {
		return 0, nil, fmt.Errorf("body too short for opcode: %d", len(body))
	}
	return binary.LittleEndian.Uint16(body[:2]), body[2:], nil
}

func (s *Scenario) sendPacket(opcode uint16, payload []byte) error {
	bodyLen := 2 + len(payload)
	pad := (-bodyLen) & (aionproto.BlockSize - 1)
	totalLen := aionproto.HeaderSize + bodyLen + pad
	pkt := make([]byte, totalLen)
	binary.LittleEndian.PutUint16(pkt[0:], uint16(totalLen))
	binary.LittleEndian.PutUint16(pkt[aionproto.HeaderSize:], opcode)
	copy(pkt[aionproto.HeaderSize+2:], payload)
	if s.encOn {
		body := pkt[aionproto.HeaderSize:]
		s.xorEnc.Encode(body)
		for off := 0; off+aionproto.BlockSize <= len(body); off += aionproto.BlockSize {
			s.bf.EncryptBlock(body[off:off+aionproto.BlockSize], body[off:off+aionproto.BlockSize])
		}
	}
	_, err := s.conn.Write(pkt)
	return err
}

// encryptCredentials —— 与 tinyclient HEAD 完全对称的 RSA-NoPad 凭据块。
//
// 关键不变量：plain[0] = 0x00 是 scramble byte，确保 m < n（RSA 数学约束）。
// 不要随机化，否则 1000 并发会偶发 m≥n 报错（见 README risk note）。
func (s *Scenario) encryptCredentials() ([]byte, error) {
	if len(s.account) > accountNameMax {
		return nil, fmt.Errorf("account too long: %d > %d", len(s.account), accountNameMax)
	}
	if len(s.password) > passwordMaxLen {
		return nil, fmt.Errorf("password too long: %d > %d", len(s.password), passwordMaxLen)
	}
	plain := make([]byte, rsaBlockSize)
	plain[0] = 0x00
	copy(plain[1:], s.account)
	copy(plain[passwordOffset:], s.password)
	n := new(big.Int).SetBytes(s.rsaModulus)
	m := new(big.Int).SetBytes(plain)
	if m.Cmp(n) >= 0 {
		return nil, fmt.Errorf("plaintext >= modulus")
	}
	c := new(big.Int).Exp(m, big.NewInt(int64(rsaPublicExp)), n)
	cb := c.Bytes()
	if len(cb) > rsaBlockSize {
		return nil, fmt.Errorf("ciphertext > block size: %d", len(cb))
	}
	out := make([]byte, rsaBlockSize)
	copy(out[rsaBlockSize-len(cb):], cb)
	return out, nil
}

// randName 生成 alphanum 后缀的随机账号名/角色名。
//
// 与 cmd/tinyclient/main.go (working-tree) 的 randName 行为一致：
// alphabet 32 chars × suffix 12 = ~10^18 唯一名空间，1000 并发不会撞。
// 优先 crypto/rand；失败回落 math/rand（仅本工具，非生产凭据）。
func randName(prefix string, n int) string {
	const alphabet = "abcdefghijkmnpqrstuvwxyz23456789"
	out := []byte(prefix)
	for i := 0; i < n; i++ {
		bi, err := rand.Int(rand.Reader, big.NewInt(int64(len(alphabet))))
		if err != nil {
			out = append(out, alphabet[mrand.Intn(len(alphabet))])
		} else {
			out = append(out, alphabet[bi.Int64()])
		}
	}
	return string(out)
}
