# tinyclient — AionCore 5.8 端到端 boot-test 客户端

## 用途

`tinyclient` 是 AionCore 5.8 五进程拓扑（gateway/world/chat/logd/admin + NATS + Redis + PG）端到端冒烟测试的最小 Go 客户端。它走完整的 AION 5.8 协议握手：

```
auth :2108     game :7777
   ↓               ↓
SM_KEY            SM_SESSION_KEY
CM_AUTH_LOGIN    CM_SESSION_CONFIRM
SM_LOGIN_OK      SM_CHARACTER_LIST  (← World 通过 NATS player.enter 触发)
CM_PLAY
SM_PLAY_OK
```

成功跑完意味着以下链路全部通畅：

1. **Gateway 加密协议栈** — BF-LE / RSA-NoPad / XOR(seed=1234)
2. **PostgreSQL** — `aion_account_db.ap_verify_account` 凭据校验
3. **Redis** — 一次性 session token 颁发与验证
4. **NATS JetStream** — `player.login` / `player.enter` 事件流
5. **World ECS + Lua** — 接收 player.enter 后通过 PG SP 拉角色列表，回包给 gateway

任一环掉，tinyclient 立即非零退出，错误堆栈定位到具体阶段。

## 与 `bin/proto_simulator.py` 的关系

两者协议实现完全等价、互为对照：

| 维度 | tinyclient (Go) | proto_simulator.py |
|------|-----------------|--------------------|
| 加密栈 | 复用 `internal/crypto` | 独立 Python 实现 |
| 交叉验证 | 与 server 100% 共享代码路径 | 独立第三方实现，能发现 server 自洽错位 |
| CI 友好 | 编译型、零 runtime 依赖 | 依赖 Python + pycryptodome |
| 速度 | ~110ms/次 | ~140ms/次 |

**保留两个版本**是有意为之：proto_simulator.py 用独立栈才能侦测 server-only-bug。

## 用法

```bash
# 默认参数（账号 shiguang / 密码 hunter2，gateway 在 127.0.0.1）
./bin/tinyclient.exe

# 自定义
./bin/tinyclient.exe --host 127.0.0.1 --account dbg_001 --password ""

# 仅跑 auth 阶段（用于隔离 game-port 问题）
./bin/tinyclient.exe --auth-only
```

成功输出末尾会有：

```
time=... level=INFO msg="tinyclient: end-to-end OK" elapsed=110ms
```

## 一键 boot-test

`Makefile` 提供 `boot-test` target，会按依赖顺序起：

1. NATS server (4222)
2. devredis (6379)
3. 5 个 AionCore 进程（gateway/world/chat/logd/admin）
4. 跑 tinyclient

```bash
cd D:/拾光ai/ACE_5.8/server
make boot-test
```

PostgreSQL 假定已作为 Windows 服务在跑（`postgresql-x64-16`）。

## 已知现象

- **chars=0** 是预期 — Sprint 0 阶段 `dbg_*` 账号在 `aion_world_live.user_data` 没插过角色行
- **gateway/world 已被外部启动** — Makefile 用 `tasklist` 检测，不会重复起
- **chat/logd/admin** 当前是占位实现，仅证明 boot 不 panic（Phase S-3/S-4 未到）

## 扩展

加新 opcode 测试：在 `gamePhase` 后增加 `c.sendPacket(aionproto.CM_XXX, payload)` + `c.readPacket()` 即可。所有加密链路自动接管。
