-- scripts/lib/loot.lua
-- Round 11 A8 — patch 06: NPC loot drop 引擎 (高熵机制核心战场)。
--
-- 战略命题: "玩家不能 5 次副本就把一切算清楚"。
--   * 副本 boss = 单点高密度 (instance.lua:on_boss_kill, patch 02)
--   * 普通 mob loot = 连续低密度的多样性来源 (本文件)
--   * 没有 mob loot → 高熵系统的"出口"被堵死, entropy 全是 unit-test 死路。
--
-- 本文件提供的是 *引擎*: 注册接口 + 抽样 + 分发。 *数据* (每个 mob 的 drop
-- table) 由 scripts/data/loot_tables.lua 提供 (Round 11 B8 并行 round 产出),
-- 本 round 严格不碰 scripts/data/。
--
-- ============================================================
-- API 合约 (locked — 数据侧 B8 / 调用侧 events/on_kill.lua 都依赖)
-- ============================================================
--
--   loot.register_table(mob_template_id, def)
--     注册一个 mob 的掉落表。多次注册同 mob_template_id 视为覆盖。
--     def 结构:
--       {
--         drops = {
--           { item_id = 100000001, prob = 0.05, count_min = 1, count_max = 1,
--             class = "weapon", tier = "rare",   affix = true  },
--           { item_id = 200001,    prob = 0.30, count_min = 1, count_max = 3,
--             class = "potion",   tier = "common", affix = false },
--           ...
--         },
--         max_drops = 3,   -- 单次击杀最多产出 N 件 (clamp, 防数据错配爆库存)
--       }
--
--   loot.roll(mob_template_id, killer_session) -> drops[]
--     纯函数: 同 (mob_template_id, killer_session) 输入 → 同 drops[] 输出。
--     killer_session 需提供 .entity_id 用于 PRNG seed 派生 (forge_id 用 char_id);
--     未注册的 mob_template_id 返回空表 ({}), 不 panic, 不 log warn。
--     返回 entry 形状: {item_id, count, class, tier, affix}
--
--   loot.roll_and_grant(killer_eid, mob_template_id, killer_level)
--     生产路径包装: events/on_kill.lua 调用。内部走 loot.roll → 对每条
--     drop 按 (class, affix) 分发到 entropy.add_item_with_random_attr (affix)
--     / entropy.add_item_with_stones (装备 non-affix) / player.add_item (consumable)。
--     killer_level 当前未参与概率调整 (留 future, 例如 lv > mob+5 触发概率衰减)。
--
-- ============================================================
-- 设计约束
-- ============================================================
--
--   1. **确定性**: roll() 是纯函数 — 同 mob+session 永远同 drops。
--      seed = mob_template_id * G + killer_eid * H (LCG mix), 决定每件 drop
--      的 RNG state。这让 wave-7 demo 服可重放、QA 可断言、玩家能验证。
--   2. **Stream 隔离**: loot 用独立 stream_id=300, 与 v0/v1/v2 分流, 玩家
--      不会看到 "loot drop 跟我装备词缀有相关性" 的 spurious pattern。
--   3. **max_drops clamp**: 数据侧若不慎写 30 个 prob=1.0 的 drop, 玩家击杀
--      一次得 30 件 → 服务端短期 OOM。max_drops (默认 3) 是硬上限。
--   4. **不破 v0/v1 已有路径**: loot 是 *新* mint 路径 (mob 死了产装备),
--      不替换 mail/instance/quest 已经接入的 entropy.add_item_with_*。
--   5. **forge_id 一致性**: roll_and_grant 内部走 entropy.add_item_with_*,
--      forge_id 由 helper 自己算; loot.roll 不预算 forge_id (避免重复算)。

loot = loot or {}

-- 注册表: mob_template_id -> def
loot._tables = loot._tables or {}

-- ============================================================
-- §1 — Registration API
-- ============================================================

-- loot.register_table(mob_template_id, def)
function loot.register_table(mob_template_id, def)
    local tid = tonumber(mob_template_id)
    if not tid or tid <= 0 then
        log.warn("loot.register_table: invalid mob_template_id="
            .. tostring(mob_template_id))
        return
    end
    if type(def) ~= "table" or type(def.drops) ~= "table" then
        log.warn("loot.register_table: invalid def for tid=" .. tostring(tid))
        return
    end
    -- 默认 max_drops=3, 数据侧不写也安全
    def.max_drops = tonumber(def.max_drops) or 3
    if def.max_drops < 1 then def.max_drops = 1 end
    loot._tables[tid] = def
end

-- loot.has_table(mob_template_id) -> bool
function loot.has_table(mob_template_id)
    return loot._tables[tonumber(mob_template_id) or 0] ~= nil
end

-- loot.unregister_table(mob_template_id) — 测试用; 生产从不调
function loot.unregister_table(mob_template_id)
    local tid = tonumber(mob_template_id) or 0
    loot._tables[tid] = nil
end

-- loot.clear_all() — 测试用; 在 setup 时清掉残余 table
function loot.clear_all()
    loot._tables = {}
end

-- ============================================================
-- §2 — PRNG (与 v0/v1 同核, 但 stream_id=300 隔离)
-- ============================================================

local LCG_MUL = 1664525
local LCG_ADD = 1013904223
local LCG_MOD = 2147483648  -- 2^31
local STREAM_ID_LOOT = 300  -- 与 v0(0)/v1(1..n)/season_pool(200) 隔离

local function lcg_next(state)
    local s = (state * LCG_MUL + LCG_ADD) % LCG_MOD
    return s, s / LCG_MOD
end

-- derive_seed(mob_tid, killer_eid, slot_index, season_seed)
-- 把 (mob, killer, drop_slot, season) 4 元组混入一个 PRNG state。
-- season_seed 让"本周 mob X 在 killer Y 身上的 drop"跨周变化, 实现"同 mob
-- 不是 5 次就摸清"。
local function derive_seed(mob_tid, killer_eid, slot_index, season_seed)
    local g = 2654435761  -- 黄金分割比素数 (Knuth)
    local h = 2246822519
    local k = 134775813
    local s = ((mob_tid     * g) % LCG_MOD
            +  (killer_eid  * h) % LCG_MOD
            +  (slot_index  * k) % LCG_MOD
            +  (season_seed or 0)
            +  STREAM_ID_LOOT * 31337) % LCG_MOD
    return (s * LCG_MUL + LCG_ADD) % LCG_MOD
end

-- ============================================================
-- §3 — Pure roll (loot.roll)
-- ============================================================

-- loot.roll(mob_template_id, killer_session) -> drops[]
--   killer_session: { entity_id = N }   (extra 字段被忽略, 兼容性保留)
function loot.roll(mob_template_id, killer_session)
    local tid = tonumber(mob_template_id) or 0
    local def = loot._tables[tid]
    if not def then return {} end

    local killer_eid = (killer_session and tonumber(killer_session.entity_id)) or 0
    local season_seed = (entropy and entropy.season_seed and
                         entropy.season_seed()) or 0

    local out = {}
    local max_drops = def.max_drops or 3
    -- 每个 drop entry 一个独立 PRNG state (slot_index 派生子流), 互不相关
    for i, entry in ipairs(def.drops) do
        if #out >= max_drops then break end
        local prob = tonumber(entry.prob) or 0
        if prob > 0 and entry.item_id then
            local state = derive_seed(tid, killer_eid, i, season_seed)
            local _, r = lcg_next(state)
            if r < prob then
                local cmin = tonumber(entry.count_min) or 1
                local cmax = tonumber(entry.count_max) or cmin
                if cmax < cmin then cmax = cmin end
                local _, r2 = lcg_next(state)
                local count = cmin + math.floor(r2 * (cmax - cmin + 1))
                if count > cmax then count = cmax end
                if count < 1 then count = 1 end
                out[#out + 1] = {
                    item_id = tonumber(entry.item_id),
                    count   = count,
                    class   = entry.class or "weapon",
                    tier    = entry.tier  or "common",
                    affix   = entry.affix and true or false,
                }
            end
        end
    end
    return out
end

-- ============================================================
-- §4 — Production grant path (loot.roll_and_grant)
-- ============================================================

-- loot.roll_and_grant(killer_eid, mob_template_id, killer_level) -> n_granted
-- 生产路径: events/on_kill.lua 调。失败的 grant (如 inv 满) 不阻断后续 drop。
function loot.roll_and_grant(killer_eid, mob_template_id, killer_level)
    local eid = tonumber(killer_eid) or 0
    if eid <= 0 then return 0 end
    local gw = entity and entity.get_gateway_id and entity.get_gateway_id(eid)
    if not gw then return 0 end  -- killer 不是玩家 → 没有 gateway, 跳

    local drops = loot.roll(mob_template_id, { entity_id = eid })
    if #drops == 0 then return 0 end

    local class_name = (class_names and class_names.of_entity(eid)) or "default"
    local race       = (entity and entity.get_stat and
                       entity.get_stat(eid, "faction")) or 0
    local seed       = (entropy and entropy.season_seed and
                       entropy.season_seed()) or 0

    local n = 0
    for _, d in ipairs(drops) do
        if d.affix and entropy and entropy.add_item_with_random_attr then
            -- v1 路径: 武器/防具 affix drop → random_attr 词缀
            entropy.add_item_with_random_attr(gw, d.item_id, d.count,
                class_name, d.tier, race, seed)
            n = n + 1
        elseif d.class == "weapon" or d.class == "armor" or d.class == "accessory" then
            -- v0 路径: 装备非 affix → manastone only
            if entropy and entropy.add_item_with_stones then
                entropy.add_item_with_stones(gw, d.item_id, d.count,
                    d.class, d.tier, seed)
                n = n + 1
            end
        else
            -- consumable / quest item: 走裸 player.add_item, 不挂 entropy
            if player and player.add_item then
                player.add_item(gw, d.item_id, d.count)
                n = n + 1
            end
        end
    end
    if n > 0 and log and log.info then
        log.info(string.format(
            "[loot] killer_eid=%d mob_tid=%s drops=%d granted=%d",
            eid, tostring(mob_template_id), #drops, n))
    end
    return n
end

-- ============================================================
-- §5 — Self-check (load 时跑)
-- ============================================================
do
    -- 未注册 mob → 空表 + 不 panic
    local empty = loot.roll(99999, { entity_id = 1 })
    assert(type(empty) == "table" and #empty == 0,
        "loot.roll for unregistered mob must return empty table")

    -- 注册 + roll 一次保证 deterministic shape
    loot.register_table(199001, {
        drops = {
            { item_id = 100000001, prob = 1.0, count_min = 1, count_max = 1,
              class = "weapon", tier = "rare", affix = true },
        },
        max_drops = 1,
    })
    local d1 = loot.roll(199001, { entity_id = 7 })
    local d2 = loot.roll(199001, { entity_id = 7 })
    assert(#d1 == 1 and #d2 == 1, "deterministic loot must produce same count")
    assert(d1[1].item_id == d2[1].item_id, "deterministic loot must produce same item")
    -- 不污染生产数据: 注销自检表
    loot.unregister_table(199001)
end
