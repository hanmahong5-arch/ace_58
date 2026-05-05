# ADR-0002: Blowfish 小端非标准实现

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-12
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

NCSoft 5.8 客户端在 7777 (Game) 端口和早期 2106 (Auth) 端口使用 Blowfish 块加密做
应用层包加密。但客户端的实现在以下两个层面偏离 Bruce Schneier 的标准：

1. **块 I/O 字节序**：标准 Blowfish 把 8-byte block 当成两个 big-endian uint32（XL / XR），
   key schedule 用同样的字节序消化 P-array。NCSoft 客户端把每个 8-byte block 当成
   两个 **little-endian** uint32 读写，但 key schedule 仍然标准。结果：明文一致、
   密文与标准 Blowfish 完全不同。
2. **生态影响**：Go `golang.org/x/crypto/blowfish` 严格遵守 Schneier 标准（big-endian
   block I/O）；用它解 NCSoft 包会得到字节序颠倒的垃圾。同样 OpenSSL `EVP_bf_ecb`、
   Java `Cipher.getInstance("Blowfish")` 都不能直接用。

如果不解决，连 SM_KEY 握手包都解不开，客户端连不上服务器。

历史上这个坑在 NCSoft 自家 C++ 客户端外被多次踩到：AL-Login（开源 AION 模拟器）、
Beyond-Aion Java、ShiguangGate-v1 C# fork、AionCore C++20 归档版都自写过一遍。

## 决策 (Decision)

我们自写 Blowfish-LE 实现，放在 `src/internal/crypto/blowfish_le.go`，并禁止任何
模块（包括测试）引入 `golang.org/x/crypto/blowfish` 作为生产依赖。

实现细节：

- **Key schedule 标准**：P-array 初始化、F-function、16 轮 Feistel 都按 Schneier
  原始论文实现
- **Block I/O 小端**：`Encrypt(block [8]byte)` 内部用 `binary.LittleEndian.Uint32`
  读 XL / XR，加密后用 `binary.LittleEndian.PutUint32` 写回
- **测试向量**：测试集来自归档 C++ 版（`_archive/aioncore-cpp-20260412.tar.gz`
  里的 `shared/crypto/blowfish.*`）和 ShiguangGate-v1 C# 反编译参考
- **不暴露 BE 模式**：API 只导出 LE 一种用法，避免误用

## 后果 (Consequences)

### 正面 (Positive)

- 5.8 客户端首包 SM_KEY 解密 / 任何后续包加解密都正确
- 测试向量复用归档 C++ 实现 + Beyond-Aion / AL-Login 公开向量，回归网兜得很厚
- 用纯 Go stdlib (`encoding/binary`)，不引 CGO，跨平台编译 0 摩擦

### 负面 (Negative)

- 维护负担：未来 Go 升 stdlib 时 Blowfish 实现要自检
- 安全审计时要小心：自实现密码学一向是高危区，必须有完整测试 + bench
- 新人容易"顺手优化"换成 stdlib，破坏兼容性 — 必须在 CLAUDE.md / dev-guide 反复告警

### 中性 / 影响 (Neutral)

- 目录 `internal/crypto/` 永远 own 这块代码，不能外包给第三方库
- 任何 Blowfish 相关 PR 必须跑 `go test ./internal/crypto -run TestBlowfishLE`
- C# / Java / Rust 平行实现要保持向量一致性

## 备选方案 (Alternatives Considered)

- **patch `golang.org/x/crypto/blowfish` 加 LE 模式**：
  - 否 — 上游不会接受非标准 PR；fork 会污染 vendoring；无 vendor 时升级会爆炸
- **CGO 调 OpenSSL 自写 LE wrapper**：
  - 否 — 部署多一个原生依赖；Windows 服务器上 CGO 跨编译已知坑
- **byte-swap hack**：每次加解密前 swap 4 byte，调用标准 BE Blowfish：
  - 否 — 性能差（多两次 swap / block）；语义上掩盖问题；测试时心智模型乱
- **整体协议改成 AES-GCM 之类的现代密码套件**：
  - 否 — 客户端是 NCSoft 35GB 二进制，改协议要 hex patch 客户端，成本天文
- **直接用 ShiguangGate-v1 C# 实现做 sidecar**：
  - 否 — 多一个进程 + 多一个 RPC 跳；性能 / 部署都不划算

## 引用 (References)

- `server/CLAUDE.md` — Key Constraint #4 "Blowfish is little-endian"
- `server/doc/architecture.md` §3 Wire Protocol Layers
- `server/doc/dev-guide.md` §2.4 Crypto Implementation
- `src/internal/crypto/blowfish_le.go` — 实现
- 归档 C++ 参考：`_archive/aioncore-cpp-20260412.tar.gz` 内 `shared/crypto/blowfish.*`
- 平行实现：`tools/ShiguangGate-v1/AionCommons-decompiled/`（C# 反编译）、
  `_archive/ACE_5.8_RS/crates/aion-proto/`（Rust 归档）
- Bruce Schneier, "Description of a New Variable-Length Key, 64-Bit Block Cipher
  (Blowfish)", 1993
