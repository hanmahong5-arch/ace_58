# AionCore 5.8 术语表 / Glossary

> 用法：看到陌生术语就在此搜索；找不到则补一条 PR。
> 配套阅读：[`architecture.md`](./architecture.md) ·
> [`opcodes.md`](./opcodes.md) · [`lua-api.md`](./lua-api.md) ·
> [`dev-guide.md`](./dev-guide.md)。

## 索引

- [游戏内 / Game Lore](#游戏内--game-lore)
- [协议 / Protocol](#协议--protocol)
- [架构 / Architecture](#架构--architecture)
- [运维 / Operations](#运维--operations)
- [数据库 / Database](#数据库--database)
- [引用 / References](#引用--references)

---

## 游戏内 / Game Lore

每条 entry: 中文 / 一句话定义 / 引用源（路径或文档）。

- **AION** — 韩国 NCSoft 出品的 MMORPG，2008 首发；本仓库实现 5.8 版本协议。
- **Atreia** — 游戏世界名（一颗破碎的星球，分天上人间两侧）。
- **Elyos** (天族) — 光明阵营，居住于 Sanctum；race_id = 0；见 `scripts/lib/pvp.lua` `FACTION_ELYOS`。
- **Asmodian** (魔族) — 黑暗阵营，居住于 Pandaemonium；race_id = 1；见 `scripts/lib/pvp.lua` `FACTION_ASMODIAN`。
- **Daevas** (天神) — 玩家身份；觉醒后获得飞翼，可进入 Abyss。
- **Abyss** (深渊) — 中立 PvPvE 战场区域，AION 标志性玩法。
- **Abyss Points / AP** — Abyss 击杀获得的货币 / 排名分；100 ± 10 per level diff，clamp [10, 500]；见 `scripts/lib/pvp.lua` `kill_ap`。
- **Kinah** — 游戏内通用货币（gold-equivalent）；用于商店 / 仓库费 / 拍卖手续费。
- **Sanctum / Pandaemonium** — 双族首都；副本 / 仓库 / 拍卖 NPC 的常驻地。
- **Solorius / Pernos** — 经典 NPC（任务发布者 / 教官，举例）。
- **Stigma** — 印记技能（一种装备槽 + 技能扩展，来自 NCSoft 原系统）。
- **Manastone** — 镶嵌石；entropy v0 的核心载体；见 `scripts/entropy/manastone_pool.lua` 与 `manastone_roll.lua`。
- **Godstone** — 神石（武器特殊触发）；entropy 后续候选机制。
- **Legion** (军团) — 持久组织；与 group（临时队伍）相对；见 `scripts/lib/legion.lua`。
- **Brigade General / Centurion / Legionary / Deputy** — 军团 4 级军衔（rank 0/1/3/2）；见 `scripts/lib/legion.lua` 头注释。
- **Group** (队伍) — 临时组队；见 `scripts/lib/group.lua`。
- **Instance / Dungeon** — 副本；独立 WorldID 的 phased 区域；见 `scripts/lib/instance.lua`。
- **Haramel** — 1-10 单人副本（lv1-10，4h cooldown）；见 `scripts/instances/inst_300040000_haramel.lua`。
- **Beshmundir Temple** — 55 级 6 人副本（18h cooldown）；见 `scripts/instances/inst_300320000_beshmundir.lua`。
- **Buff / DoT** — 战斗增益 / Damage-over-Time 持续伤害；见 `scripts/lib/buff.lua`。
- **Flight / Glide / Ground** — 三态飞行机（GROUND=0 / GLIDE=1 / FLY=2）；FP 在飞行时按 tick 消耗；见 `scripts/lib/flight.lua`。
- **Bind Point** — 复活绑定点；见 PG SP `aion_GetBindPoint` / `aion_SetBindPoint`。
- **Cooltime / Cooldown** — 技能 / 副本冷却时间；副本 cooldown 通过 `aion_setuserinstance_20171122` SP 持久化。
- **Auction House / AH** — 拍卖行；listing fee 2%、最长 48h；见 `scripts/lib/auction.lua`（S-16）。
- **Mailbox** — 邮件；附件 + Kinah 原子领取；见 `scripts/lib/mail.lua`（S-14）。
- **Warehouse** — 账户仓库；通过 user_item.warehouse 列分区（0=inventory, 2=warehouse）；见 `scripts/lib/warehouse.lua`（S-15）。
- **Shop / NPC Vendor** — NPC 商店；见 `scripts/lib/shop.lua`（S-8）。
- **Quest** — 任务；状态机 + 奖励发放；见 `scripts/quests/quest_*.lua`。
- **Skill** — 技能；冷却 / 法力 / 施法时间；每个文件一个技能；见 `scripts/skills/skill_*.lua`。
- **Starter Kit** — 新角色入场礼包（武器 / 药水）；见 `scripts/lib/starter_kit.lua`。
- **Loot** — 怪物 / 副本掉落表；见 `scripts/lib/loot.lua`。

## 协议 / Protocol

跨链接到 [`opcodes.md`](./opcodes.md) / [`lua-api.md`](./lua-api.md) / [`architecture.md`](./architecture.md) §3。

- **CM_*** — Client → Server 包（如 `CM_MOVE` = 0x0A，`CM_USE_SKILL` = 0x0E，`CM_INSTANCE_ENTER` = 0xCF）。
- **SM_*** — Server → Client 包（如 `SM_KEY` = 0x00，`SM_SKILL_RESULT` = 0x5E，`SM_INSTANCE_ENTER_RESULT` = 0xD0）。
- **Opcode** — auth port (:2108) 是 u8；game port (:7777) 是 u16；定义见 `src/internal/aionproto/opcodes.go` + [`opcodes.md`](./opcodes.md)。
- **BF-LE / Blowfish-LE** — 小端 Blowfish；NCSoft 非标准（标准库 `crypto/blowfish` 是大端，不能用）；实现见 `src/internal/crypto/blowfish_le.go`。
- **RSA-NoPad** — RSA-1024 无填充；用于 `CM_AUTH_LOGIN` 凭据加密；账号名 ≤ 17 字符（块大小硬限）。
- **XOR seed=1234** — XOR-first ADD-stored 流加密；5.8 client 忽略 XOR 校验（必须容忍）。
- **session key** — 每会话一次性 key；gateway 在 `SM_SESSION_KEY` (0x1A) 下发后用其加 stream 包。
- **Frame** — 包帧 = `[u16 length LE][payload]`；length 含自身，最小 3。
- **SM_KEY** (0x00) — 首包不加密，承载 RSA 模数 + 静态 BF key。

## 架构 / Architecture

- **gateway / world / chat / logd / admin** — 5 服务进程；见 [`architecture.md`](./architecture.md) §2。
- **VMPool** — Lua VM 对象池；见 `src/internal/luahost/vm.go` + `vmpool_test.go`。
- **Bridge** — Go ↔ Lua 桥；注入 db / entity / player / log / jobq 等全局表；见 `src/internal/luahost/bridge.go`。
- **LuaInvoker** — Go 调 Lua 全局函数的接口；见 `src/internal/luahost/invoker.go`。
- **ECS** — Entity-Component-System；in-memory + 单线程；见 `src/internal/ecs/`。
- **WorldID** — ECS 世界标识；副本范围一般 ≥ 300000000（如 Haramel = 300040000）。
- **Hot-reload** — Lua 文件 1 秒热重载；VM 池整池 swap，不重启进程。
- **Sandbox** — Lua VM 沙箱；仅暴露 base / table / string / math / `os.time`；不暴露 io / os.execute。
- **JetStream** — NATS 持久化流；inter-service 事件总线；见 `src/internal/ipc/`。
- **jobq** — 后台任务队列；asynq + Redis；用于拍卖到期 / 副本到期 / 邮件投递；见 `src/internal/jobq/`。
- **Embedded migration** — Go binary 内嵌 SQL migration；goose + `go:embed`；见 `src/internal/database/migrate.go`。
- **dual-mirror** — `sql/schema/` ↔ `src/internal/database/migrations/` 双副本（`go:embed` 不能跨包根，必须镜像）。
- **Jay Lee 模式** — 启动时一次性把模板灌进 ECS 组件（不在运行时查 DB）；见 [`architecture.md`](./architecture.md) §4.4。

## 运维 / Operations

- **Makefile targets** — `build` / `boot` / `boot-test` / `stop` / `lint` / `test` / `cover` / `bench`；见 server 根 Makefile。
- **goose** — PG migration 工具（`pressly/goose/v3`）；marker 见下方 Database 节。
- **devredis** — miniredis 单二进制开发版 Redis；由 `make boot` 启动。
- **nats-server** — JetStream broker；由 `make boot` 启动。
- **tinyclient** — 端到端 smoke 客户端；见 `src/cmd/tinyclient/`。
- **dev / prod** — 双环境拓扑；端口 / rates / log 级别不同；见 `../CLAUDE.md` "Prod vs Dev Quick Reference"。
- **plan-critic** — Gemini 红队评审 plan 工具（外部 skill；触发条件见全局 `CLAUDE.md`）。

## 数据库 / Database

- **SP** — Stored Procedure（PL/pgSQL function）；1314 个移植自 NCSoft T-SQL；见 `sql/schema/00*_sp_*.sql`。
- **aion_world_live** — 角色 / 物品 / 公会 / 邮件 / 拍卖；约 1063 SP。
- **aion_account_db** — 账号认证；约 52 SP。
- **aion_account_cache_db** — 会话 / 排行；约 101 SP。
- **aion_gm** — GM 操作；约 183 SP。
- **delete_date = 0** — soft-delete 过滤约定（每个 user_data SELECT 必带）。
- **goose marker** — `-- +goose Up`、`-- +goose Down`、`-- +goose StatementBegin/End`；见 [`dev-guide.md`](./dev-guide.md)。
- **CallSP** — Go 端 SP 调用入口；见 `src/internal/database/`；Lua 端等价为 `db.call("aion_xxx", ...)`。
- **127.0.0.1 only** — PG 永远不暴露公网（红线，2026-04-11 勒索教训）。

## 引用 / References

- 架构总览：[`architecture.md`](./architecture.md)
- 开发指南（Source of Truth）：[`dev-guide.md`](./dev-guide.md)
- 协议字典：[`opcodes.md`](./opcodes.md)
- Lua API：[`lua-api.md`](./lua-api.md)
- 代码风格：[`style.md`](./style.md)
- 服务器级 CLAUDE.md：[`../CLAUDE.md`](../CLAUDE.md)
- 工作区入口：[`../../CLAUDE.md`](../../CLAUDE.md)
- 中文 README：[`../README.zh-CN.md`](../README.zh-CN.md)

---

> 维护规则：发现新术语 + 重要术语先入此表，再写代码引用。
> 命名歧义（如 group vs legion / inventory vs warehouse / cooltime vs cooldown）务必双向 cross-link。
