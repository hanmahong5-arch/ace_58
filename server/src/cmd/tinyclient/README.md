# tinyclient — AionCore 5.8 端到端测试 + 高熵 PvE 链演示客户端

## 用途

`tinyclient` 是 AionCore 5.8 五进程拓扑（gateway/world/chat/logd/admin + NATS + Redis + PG）端到端冒烟 **+** 「光辉永恒」高熵命题第一次端到端实测的最小 Go 客户端。

它复用主项目 `internal/crypto` + `internal/aionproto`，与服务端使用完全一致的 BF-LE / RSA-NoPad / XOR(seed=1234) 实现，避免任何"我以为对"但实际错位的协议漂移问题。

## 阶段化 (`--stage`)

| stage    | 包流向                                                               | 退出条件                |
|----------|----------------------------------------------------------------------|------------------------|
| `login`  | SM_KEY → CM_AUTH_LOGIN → SM_LOGIN_OK → CM_PLAY → SM_PLAY_OK          | auth 端口握手完成      |
| `list`   | + SM_SESSION_KEY → CM_SESSION_CONFIRM → SM_CHARACTER_LIST            | 收到角色列表           |
| `create` | + （若 list 空）CM_CREATE_CHARACTER → SM_CREATE_CHARACTER_RESPONSE   | 角色创建成功 / 已存在  |
| `select` | + （5.8 客户端无独立 select 包，本步仅作为顺序占位）                 | 直接进入下一阶段       |
| `world`  | + CM_ENTER_WORLD → SM_ENTER_WORLD_RESPONSE                           | 世界进入完成           |
| `attack` | + CM_USE_SKILL × N → SM_DIE                                          | mob 死亡               |
| `loot`   | + SM_LOOT_AVAILABLE → CM_LOOT_ITEM → SM_LOOT_ITEMLIST                | 收到 stones + forge_id |

默认 `--stage loot`，跑全链路。任何阶段失败 / 收到意外 packet → 详细 log + exit 1。

## 用法

```bash
# 完整 PvE 链 — 命题验证演示
cd D:/拾光ai/ACE_5.8/server
./bin/tinyclient.exe --account shiguang --password hunter2 \
    --mob-id 700123 --skill-id 1001

# 中途打断（分阶段调试）
./bin/tinyclient.exe --stage list           # 仅到角色列表
./bin/tinyclient.exe --stage world          # 进世界但不打 mob
./bin/tinyclient.exe --stage attack --mob-id 700123  # 打 mob 但不拾取

# 兼容 Round 10 F4 旧 boot-test 行为
./bin/tinyclient.exe --auth-only            # 等价 --stage login
```

成功跑完 `--stage loot` 时尾部输出形如：

```
level=INFO msg="tinyclient: LOOT verified — 光辉永恒命题第一次端到端实测"
  item_id=100000001 item_uid=987654321 forge_id=F0RGE042
  stones=[1001 1002 0 1003 0 1004] non_zero_stones=4 attrs_count=2
level=INFO msg="tinyclient: end-to-end OK" elapsed=2.4s end_stage=loot
```

`stones != nil` + `non_zero_stones >= 1` + 8 字符 `forge_id` 是高熵命题验证的**机器可断言**指标。

## 命令行参数

| flag           | 默认           | 说明 |
|----------------|----------------|------|
| `--host`       | `127.0.0.1`    | gateway 主机 |
| `--auth-port`  | `2108`         | auth 端口 |
| `--game-port`  | `7777`         | game 端口 |
| `--account`    | 随机 `dbg_xxx` | 账号 (≤17 chars) |
| `--password`   | `hunter2`      | 密码 |
| `--char-name`  | 随机 `Sgxxxx`  | 角色名 (≥2 chars) |
| `--server-id`  | `10`           | 逻辑 server 选择 |
| `--mob-id`     | `0`            | 攻击目标 entity id（B8 提供）；stage>=attack 必填 |
| `--skill-id`   | `1001`         | 攻击使用的技能模板 id |
| `--stage`      | `loot`         | 最大阶段：login\|list\|create\|select\|world\|attack\|loot |
| `--auth-only`  | `false`        | (legacy) 等价 `--stage login` |

## 与 `bin/proto_simulator.py` 的关系

| 维度 | tinyclient (Go) | proto_simulator.py |
|------|-----------------|--------------------|
| 加密栈 | 复用 `internal/crypto` | 独立 Python 实现 |
| 交叉验证 | 与 server 100% 共享代码路径 | 独立第三方实现，能发现 server 自洽错位 |
| CI 友好 | 编译型、零 runtime 依赖 | 依赖 Python + pycryptodome |
| 速度 | ~110ms / login，~2s / 全 PvE 链 | ~140ms / login |

**保留两个版本**是有意为之：proto_simulator.py 用独立栈才能侦测 server-only-bug。

## 一键 boot-test

`Makefile` 提供 `boot-test` target，会按依赖顺序起：

1. NATS server (4222)
2. devredis (6379)
3. 5 个 AionCore 进程（gateway/world/chat/logd/admin）
4. 跑 tinyclient（默认 `--stage loot`，但需要 `--mob-id` — 见 `make boot-test-login` 的最小路径）

```bash
cd D:/拾光ai/ACE_5.8/server
make boot-test
```

PostgreSQL 假定已作为 Windows 服务在跑（`postgresql-x64-16`）。

## 已知现象 / 失败定位

- **`SM_LOGIN_FAIL reason=0x03`** — 账号未注册。换 `--account shiguang`（已知存在）或先在 `aion_account_db.account` 插行。
- **`SM_CHARACTER_LIST count=0`** — 账号无角色，正常；下一阶段会触发 CM_CREATE_CHARACTER。
- **`create char rejected result=7`** — `aion_putchar_20160620` SP 调用失败。诊断方向：
  - PG 端 `aion_world_live` 库是否包含此 SP（见 `doc/migration/`）
  - 是否有 80+ positional 参数缺省值的问题
  - `cm_create_character.lua` 与 SP 签名是否对齐（A8 的 wiring scope）
- **`timeout waiting for SM_LOOT_AVAILABLE`** — server 端 mob 死亡未触发掉落。诊断：
  - `on_kill.lua` 是否调用 `entropy.add_item_with_stones`（B8 scope）
  - `world.spawn_npc` + AI / aggro / loot 表 wiring（B8 scope）
  - 检查 `world.log` 中 `[forge] manastone iid=...` 行验证 stones 已 roll
- **chat/logd/admin** 当前是占位实现，仅证明 boot 不 panic（Phase S-3/S-4 未到）。

## 扩展

加新 opcode 测试：在对应阶段函数（如 `attackUntilDie`）后增加 `c.sendPacket(aionproto.CM_XXX, payload)` + 等待循环即可。所有加密链路自动接管。

新阶段：在 `stageNames` 添加常量、在 `gamePhase` 添加 case 分支、在 `pve_chain_test.go` 加对应 encoder/parser 测试。
