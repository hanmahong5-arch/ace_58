# ADR-0004: ECS（Entity-Component-System）实体模型

- 状态 (Status): Accepted
- 日期 (Date): 2026-04-12
- 决策者 (Deciders): @uu114 / Claude

## 背景 (Context)

AION 5.8 服务端运行时要表达多种"运动 / 持有状态"的对象：

- 玩家（Player）：position / stat / inventory / buff / quest / group / fly state / target
- NPC（含怪物 / 商人 / 守卫 / boss）：position / stat / patrol / aggro / loot table
- 投射物 / 召唤物 / 临时实体：短生命周期 + 部分组件
- buff / debuff：依附在玩家或 NPC 上，独立 tick

要求：

1. **同一种"实体"在不同场景下有不同组件**（非战斗 NPC 没 aggro / hp，但有对话；
   被驯服的宠物有玩家归属字段而野生没有）
2. **跨进程序列化简单**：world 进程退出 / 副本到期把状态推回 PG SP 时，组件视图
   要好转 JSON / proto
3. **行为（System）与数据（Component）分离**：buff tick / aggro 计算 / position
   broadcast 要能各自独立测试
4. **Lua 能直接读写实体状态**：`entity.set_stat(eid, "hp", 100)` 之类的桥接

如果用传统 OOP（`Player extends LivingEntity`），扩展受限：要给宠物加"驯服时间"
字段就得改基类，破坏 NPC 的内存布局；要给某个副本里的特定怪物加"分阶段属性"几乎
要重写继承链。

游戏行业对 ECS 的成功案例：Minecraft / Overwatch / Insomniac 各家自家引擎、Bevy
（Rust）、Unity DOTS。MMO 服务端用 ECS 也不罕见（Aion-Lightning 部分组件化）。

## 决策 (Decision)

我们采用轻量自写 ECS（`src/internal/ecs/`），按以下设计：

- **Entity = `uint64`**：不可变 ID，World 容器内自增，重用通过 generation bit 解决
- **Component = `interface{}` (in `map[ComponentTypeID]any`)**：每个组件独立 struct
  （Position / Stat / Buff / Inventory / AggroList / Patrol / FlyState / ...）
- **World = 内存单例**：所有 entity 在一个进程内的 World 实例里，单线程模型
  （游戏 tick 在主 goroutine，跨 goroutine 通过 channel）
- **System = 普通 Go 函数**：`func TickBuffs(w *ecs.World, dt time.Duration)`，
  不做 framework 抽象
- **Lua 桥**：`luahost.Bridge` 注入 `entity.get/set/spawn/destroy`，Lua handler 通过
  这层操作 ECS

故意保持简陋：不上 archetype / SoA / cache-friendly 那一套（NCSoft 5.8 服 boss
战 ~50 实体级，不是 Bevy 几万实体）；优先可读性 + Lua 友好性。

## 后果 (Consequences)

### 正面 (Positive)

- 数据 / 行为分离：加新组件不改既有代码，只加文件 + 在 system 里查询
- 易序列化：组件本身是 plain struct，转 JSON / 写 PG 都直白
- Lua 桥简单：Lua 只看到组件名 + 字段名，不需要理解 Go 类型继承
- 扩展副本 / 高熵 modifier 系统时几乎零摩擦（只是再加一个组件）
- 单测友好：构造一个 World + 几个 entity，跑一个 system，断言

### 负面 (Negative)

- 没有现成框架：query 性能（全 entity 遍历找有 Position 的）暂时是 O(N) map 扫
- 学习曲线：习惯 OOP 的人会想"为什么 Player 不是一个 class"
- 类型安全弱：组件取出来要 type assert，写错就 runtime panic
- 跨 goroutine 修改 World 必须走 channel，不是所有人第一次都做对

### 中性 / 影响 (Neutral)

- 状态归属约定：**ECS 持运行时态**（位置 / hp / 当前 buff / 副本进度），
  **PG SP 持持久态**（角色档案 / 物品 / 邮件），**Redis 持会话态**（token / rate
  limiter） — 三处不重叠
- ECS 不写盘：进程重启 = 玩家重新登录拉数据；副本进度作废 = 玩家可重进
- 跑 benchmark / pprof 时优先看 system 而非组件本身

## 备选方案 (Alternatives Considered)

- **OOP class hierarchy**：`Entity → LivingEntity → Player / NPC / Pet`：
  - 否 — 加组件 = 改基类，破坏既有 entity 内存布局
  - 多重继承 / mixin Go 没有；用 embed 又退化成 component
- **donburi / engo / arche 等 Go ECS 库**：
  - 否 — 三方 ECS 都为 Bevy 风格高性能场景设计，对 Lua 桥接不友好
  - 我们的 entity 数量级小，自写更简单
- **Bevy (Rust) + Go FFI**：
  - 否 — Rust + Go 跨语言对游戏服务器是过度工程；C++20 版已尝试过 ECS（archived）
- **直接用关系型表当 ECS**（每个组件一张表，entity_id 做 join）：
  - 否 — 每帧查 PG 不现实；只在持久化时用
- **Actor 模型 (Akka 风格)**：
  - 否 — 单 entity = 单 actor 的内存开销在 Go 上不划算；channel + ECS 已够

## 引用 (References)

- `src/internal/ecs/world.go`、`entity.go`、`world_buff_test.go`
- `src/internal/ecs/world_s7_test.go`、`world_coverage_test.go`
- `server/doc/architecture.md` §1 / §2 / §5（"在线玩家位置 / buff → ECS in-memory"）
- `server/doc/dev-guide.md` §1 三层架构 / §3 Lua API（entity.* 表）
- `src/internal/luahost/bridge.go` — entity.* 桥接
- commit `4a684ac` 初始 + `5d23478` S-19 instance 进度组件化
