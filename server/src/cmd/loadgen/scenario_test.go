package main

import (
	"encoding/binary"
	"errors"
	"io"
	"net"
	"strings"
	"testing"
	"time"

	"aion58/internal/aionproto"

	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"
)

// TestRandName_UniquePrefixed 验证 1000 次调用产生 ≥998 个唯一名（>10^18 空间，
// 实测碰撞概率 ~0；阈值留 2 个容忍度只防极端 mrand fallback 同 seed）。
func TestRandName_UniquePrefixed(t *testing.T) {
	seen := map[string]struct{}{}
	const N = 1000
	for i := 0; i < N; i++ {
		name := randName("lg_", 12)
		if !strings.HasPrefix(name, "lg_") {
			t.Fatalf("missing prefix: %q", name)
		}
		if len(name) != 3+12 {
			t.Fatalf("unexpected length: %q (%d)", name, len(name))
		}
		seen[name] = struct{}{}
	}
	if len(seen) < N-2 {
		t.Fatalf("too many collisions: %d unique out of %d", len(seen), N)
	}
}

// TestEncryptCredentials_ScrambleByteEnsuresMLessN 验证 plain[0]=0x00 后
// m < n 永远成立（给 modulus = 全 0xFF 这个最大值的 case 也通过）。
func TestEncryptCredentials_ScrambleByteEnsuresMLessN(t *testing.T) {
	s := &Scenario{
		account:    "shiguang",
		password:   "hunter2",
		rsaModulus: bytesAllFF(128),
	}
	out, err := s.encryptCredentials()
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if len(out) != 128 {
		t.Fatalf("expected 128 bytes, got %d", len(out))
	}
}

// TestEncryptCredentials_AccountTooLongRejected 边界：账号 > 17 字节必须报错。
func TestEncryptCredentials_AccountTooLongRejected(t *testing.T) {
	s := &Scenario{
		account:    strings.Repeat("a", 18),
		password:   "x",
		rsaModulus: bytesAllFF(128),
	}
	_, err := s.encryptCredentials()
	if err == nil {
		t.Fatal("expected error for over-long account")
	}
}

// TestMetrics_ObservePhaseWritesHistogramAndCounter 验证：
//   - 成功 phase 只增 histogram，不增 error counter
//   - 失败 phase 同时增 histogram + error counter
func TestMetrics_ObservePhaseWritesHistogramAndCounter(t *testing.T) {
	m := NewMetrics()

	m.ObservePhase(PhaseConnectAuth, 50*time.Millisecond, nil)
	m.ObservePhase(PhaseConnectAuth, 100*time.Millisecond, errors.New("boom"))

	histCount := histogramCount(t, m.Registry, "loadgen_phase_latency_seconds", "connect_auth")
	if histCount != 2 {
		t.Fatalf("histogram count = %d, want 2", histCount)
	}
	errCount := counterValue(t, m.Registry, "loadgen_phase_errors_total", "connect_auth")
	if errCount != 1 {
		t.Fatalf("error count = %d, want 1", errCount)
	}
}

// TestScenario_RunFailsCleanlyOnGarbage 验证：mock server 喂垃圾数据时，
// Scenario.Run 不挂、不 panic、把 phase latency 与 error 都计入 obs。
func TestScenario_RunFailsCleanlyOnGarbage(t *testing.T) {
	authPort := mustListenAndServe(t, garbageEchoHandler)
	gamePort := mustListenAndServe(t, garbageEchoHandler)

	m := NewMetrics()
	s := NewScenario("127.0.0.1", authPort, gamePort, "lg_test", "hunter2", 10, m)
	defer s.Close()

	err := s.Run()
	if err == nil {
		t.Fatal("expected error from garbage server, got nil")
	}

	// connect_auth 应该已经成功（histogram ≥1, error=0）。
	if got := histogramCount(t, m.Registry, "loadgen_phase_latency_seconds", "connect_auth"); got < 1 {
		t.Fatalf("connect_auth histogram count = %d, want ≥1", got)
	}
	if got := counterValue(t, m.Registry, "loadgen_phase_errors_total", "connect_auth"); got != 0 {
		t.Fatalf("connect_auth errors = %d, want 0 (TCP connect succeeded)", got)
	}

	// recv_sm_key 一定失败（垃圾数据无法解析为 SM_KEY）。
	if got := counterValue(t, m.Registry, "loadgen_phase_errors_total", "recv_sm_key"); got != 1 {
		t.Fatalf("recv_sm_key errors = %d, want 1", got)
	}
}

// TestScenario_RunCompletesAuthAgainstMockGateway 验证：mock 严格复刻 SM_KEY
// 但不复刻后续——Scenario 应跑过 PhaseRecvSMKey 并把 latency 写入 histogram，
// 然后在 send/recv login 阶段以 error 收尾。覆盖 BF activate / XOR seed reset
// / packet codec 全链路。
func TestScenario_RunCompletesAuthAgainstMockGateway(t *testing.T) {
	authPort := mustListenAndServe(t, smKeyOnlyHandler)
	gamePort := mustListenAndServe(t, garbageEchoHandler)

	m := NewMetrics()
	s := NewScenario("127.0.0.1", authPort, gamePort, "lg_test", "hunter2", 10, m)
	defer s.Close()

	_ = s.Run() // 不关心总返回值；只看 phase metrics。

	if got := histogramCount(t, m.Registry, "loadgen_phase_latency_seconds", "recv_sm_key"); got < 1 {
		t.Fatalf("recv_sm_key histogram count = %d, want ≥1", got)
	}
	if got := counterValue(t, m.Registry, "loadgen_phase_errors_total", "recv_sm_key"); got != 0 {
		t.Fatalf("recv_sm_key errors = %d, want 0 (mock served valid SM_KEY)", got)
	}
	if got := histogramCount(t, m.Registry, "loadgen_phase_latency_seconds", "send_auth_login"); got < 1 {
		t.Fatalf("send_auth_login should have run; histogram count = %d", got)
	}
}

// TestAllPhases_PreheatedInRegistry 验证 NewMetrics 启动时已经预热全部
// phase label，避免首次 scrape 缺线。
func TestAllPhases_PreheatedInRegistry(t *testing.T) {
	m := NewMetrics()

	families, err := m.Registry.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	var seen int
	for _, f := range families {
		if f.GetName() != "loadgen_phase_latency_seconds" {
			continue
		}
		seen = len(f.GetMetric())
		break
	}
	if seen != len(AllPhases) {
		t.Fatalf("expected %d preheated phase labels, got %d", len(AllPhases), seen)
	}
}

// --- 测试辅助 ---

func bytesAllFF(n int) []byte {
	b := make([]byte, n)
	for i := range b {
		b[i] = 0xFF
	}
	return b
}

// mustListenAndServe 在 127.0.0.1 起一个临时监听，把每个 conn 交给 handler。
// 监听器随测试结束自动关。返回端口号。
func mustListenAndServe(t *testing.T, handler func(net.Conn)) int {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { _ = ln.Close() })

	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			go handler(conn)
		}
	}()

	addr := ln.Addr().(*net.TCPAddr)
	return addr.Port
}

// garbageEchoHandler 立即写一个长度合法但 body 长度为 0 的"包"，client
// 试解析为 SM_KEY 时长度校验或 opcode 校验都会失败。
func garbageEchoHandler(conn net.Conn) {
	defer conn.Close()
	// 长度 = 4 字节（HeaderSize=2 + body=2，body 仅含 opcode 0xFFFF），合法 frame 但 opcode 错。
	_, _ = conn.Write([]byte{0x04, 0x00, 0xFF, 0xFF})
	// 然后 echo 任何后续输入直到 conn 关。
	_, _ = io.Copy(io.Discard, conn)
}

// smKeyOnlyHandler 发送一个**结构合法**的 SM_KEY clear 包，让 client
// 能跑过 PhaseRecvSMKey + activateCrypto。后续不响应——client 等
// SM_LOGIN_OK 时会 timeout 失败，正是要测的"latency 计入 + 错误计入"路径。
func smKeyOnlyHandler(conn net.Conn) {
	defer conn.Close()

	// SM_KEY layout: opcode(2) + scramble(4) + RSA modulus(128) + BF key(16) + country(1)
	body := make([]byte, 2+4+128+16+1)
	binary.LittleEndian.PutUint16(body[:2], aionproto.SM_KEY)
	for i := 6; i < 6+128; i++ {
		body[i] = 0xFF
	}
	for i := 6 + 128; i < 6+128+16; i++ {
		body[i] = byte(i & 0xFF)
	}

	totalLen := aionproto.HeaderSize + len(body)
	pkt := make([]byte, totalLen)
	binary.LittleEndian.PutUint16(pkt[0:], uint16(totalLen))
	copy(pkt[aionproto.HeaderSize:], body)
	_, _ = conn.Write(pkt)

	// 故意不响应后续，但消费 client 写入的字节避免 TCP 反压。
	_, _ = io.Copy(io.Discard, conn)
}

// histogramCount 从 registry Gather 出指定 phase label 的样本计数。
func histogramCount(t *testing.T, reg *prometheus.Registry, name, phaseLabel string) uint64 {
	t.Helper()
	families, err := reg.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	for _, f := range families {
		if f.GetName() != name {
			continue
		}
		for _, m := range f.GetMetric() {
			if matchPhaseLabel(m.GetLabel(), phaseLabel) {
				return m.GetHistogram().GetSampleCount()
			}
		}
	}
	return 0
}

// counterValue 从 registry Gather 出指定 phase label 的 counter 值。
func counterValue(t *testing.T, reg *prometheus.Registry, name, phaseLabel string) uint64 {
	t.Helper()
	families, err := reg.Gather()
	if err != nil {
		t.Fatalf("gather: %v", err)
	}
	for _, f := range families {
		if f.GetName() != name {
			continue
		}
		for _, m := range f.GetMetric() {
			if matchPhaseLabel(m.GetLabel(), phaseLabel) {
				return uint64(m.GetCounter().GetValue())
			}
		}
	}
	return 0
}

func matchPhaseLabel(labels []*dto.LabelPair, want string) bool {
	for _, lp := range labels {
		if lp.GetName() == "phase" && lp.GetValue() == want {
			return true
		}
	}
	return false
}
