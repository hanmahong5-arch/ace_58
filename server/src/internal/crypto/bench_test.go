// Package crypto — Round 11 / Task A2 benchmark surface.
//
// 这些 benchmark 与现有 blowfish_le_bench_test.go / xor_bench_test.go 互补:
// 后者覆盖单 block / 1 KiB / 16 KiB packet / 多核并行的吞吐画像，
// 这里聚焦在 "命题验证度" 的 4 个最小算子上 (Encrypt8 / Decrypt8 / XOR64
// / RSA1024Decrypt128) 并统一通过 b.SetBytes 报告 MB/s，方便 benchstat
// 与 doc/benchmarks.md 中的阈值表直接对照。
//
// 跑法 (CI 友好，无外部依赖):
//
//	cd server/src
//	go test -run='^$' -bench=. -benchtime=1x -benchmem ./internal/crypto
package crypto

import (
	"crypto/rand"
	"math/big"
	"testing"
)

// BenchmarkBlowfishLE_Encrypt8 测一个 8 字节 block 的加密成本 (gateway 出
// 包热路径的最小单元，1800 CCU 时每秒会被调用上百万次)。
// 复用 blowfish_le_test.go 的 staticKey16 fixture 保证命题一致。
func BenchmarkBlowfishLE_Encrypt8(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	src := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF}
	dst := make([]byte, 8)
	b.SetBytes(8)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher.EncryptBlock(dst, src)
	}
}

// BenchmarkBlowfishLE_Decrypt8 镜像版本，覆盖入包热路径。
func BenchmarkBlowfishLE_Decrypt8(b *testing.B) {
	cipher, err := NewBlowfishLE(staticKey16)
	if err != nil {
		b.Fatalf("NewBlowfishLE: %v", err)
	}
	// Pre-encrypt so we have valid ciphertext to decrypt — keeps semantics
	// honest (vs feeding random bytes through Decrypt).
	plain := []byte{0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF}
	enc := make([]byte, 8)
	cipher.EncryptBlock(enc, plain)
	dst := make([]byte, 8)
	b.SetBytes(8)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		cipher.DecryptBlock(dst, enc)
	}
}

// BenchmarkXORSeed_64 测一次 64 字节 buffer 的 stateful XOR (seed=1234，
// AION 5.8 所有 packet 都过这一步)。每次循环重建 cipher 以隔离 state，
// 报数 = pure XOR throughput。
func BenchmarkXORSeed_64(b *testing.B) {
	const size = 64
	src := make([]byte, size)
	for i := range src {
		src[i] = byte(i)
	}
	buf := make([]byte, size)
	b.SetBytes(int64(size))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		copy(buf, src)
		cipher := NewXORCipher() // seed = 1234
		cipher.Encode(buf)
	}
}

// BenchmarkRSA_Decrypt128 测一次 128 字节 RSA-1024 NoPad 解密 (CM_LOGIN
// 收到的 credential block 解密成本)。这是登录 path 的瓶颈，公网压测时
// 决定了 max-login-rate。
//
// fixture 在 setup 阶段一次性生成 keypair 并构造 ciphertext，hot loop 只
// 测纯 Decrypt 成本；b.SetBytes(128) 让 benchstat 直接读出 MB/s。
func BenchmarkRSA_Decrypt128(b *testing.B) {
	kp, err := GenerateRSAKeyPair()
	if err != nil {
		b.Fatalf("GenerateRSAKeyPair: %v", err)
	}

	// 构造一个合法的 credential plaintext (account/password 格式参见 rsa.go
	// 的 ParseCredentials 注释)，再用公钥裸 RSA 加密成 128 字节密文。
	plain := make([]byte, CredentialBlockSize)
	if _, err := rand.Read(plain[1:18]); err != nil {
		b.Fatalf("rand.Read: %v", err)
	}
	// 保证首字节为 0 以避免 m >= n 的边界 case。
	plain[0] = 0
	m := new(big.Int).SetBytes(plain)
	e := big.NewInt(int64(kp.PublicKeyExponent()))
	n := kp.priv.N
	c := new(big.Int).Exp(m, e, n)
	ciphertext := make([]byte, CredentialBlockSize)
	cb := c.Bytes()
	copy(ciphertext[CredentialBlockSize-len(cb):], cb)

	b.SetBytes(int64(CredentialBlockSize))
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := kp.DecryptCredentials(ciphertext); err != nil {
			b.Fatalf("DecryptCredentials: %v", err)
		}
	}
}
