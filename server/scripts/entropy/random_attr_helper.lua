-- scripts/entropy/random_attr_helper.lua
-- Round 6 C4 — entropy v1 random_attr 原型实现。
--
-- API:
--   entropy.add_item_with_random_attr(gw, item_id, count,
--                                     item_class, tier, race, season_seed)
--
--   gw          (number) — gateway_seq_id (与 player.add_item 同首参)
--   item_id     (number) — items.xml ID
--   count       (number) — stack 数量
--   item_class  (string) — 12 职业之一: "Gladiator"/"Templar"/"Assassin"/
--                          "Ranger"/"Sorcerer"/"Spiritmaster"/"Cleric"/
--                          "Chanter"/"Aethertech"/"Gunslinger"/"Songweaver"/
--                          "Bard"。未知职业 fallback 到 "default"
--   tier        (string) — "common"(4槽) | "rare"(7槽) | "epic"(10槽)
--   race        (number) — 1=Elyos / 2=Asmodian (其它值不应用 race 偏置)
--   season_seed (number) — 季节种子，与 v0 共享
--
-- 设计要点（参考 sql/migration-plan/entropy-v1-design.md §3）：
--   * 与 v0 manastone 用独立 LCG 流派生子种子，避免两个系统统计相关
--     （否则玩家会 spot pattern，1000 小时熵命题崩溃）
--   * race 偏置作为权重乘数：Elyos magicalSkillBoost ×1.1, Asmodian
--     phyAttack ×1.1（区分"明显是亚特累安刀"vs"明显是天族剑"）
--   * 12 职业 × 4 tier 偏置矩阵 — 用户决定 class+race-aware 不降级
--   * Lua 5.1 兼容：纯 LCG，无 bit32，无 // 整除
--
-- 用户 q3 决策：v1 land Cycle 17（Sprint 0 §6.3 客户端测试通过后）
--   现在仍是原型，bridge stub 只 log 不写 user_item_attribute（B 轨提供 SP 后再换）

entropy = entropy or {}

-- ============================================================
-- §1 — attr_id 池（来自 entropy-v1-design.md §1.4，删除低证据 outlier 后 23 项）
-- ============================================================

-- 每条 entry: {id="...", min=N, max=M}
-- min/max 来自 NCSoft item_random_option.xml 的实证范围（§1.3）
entropy.random_attr_pool = {
    offensive = {
        {id="phyAttack",            min=-15, max=20 },
        {id="magicalAttack",        min=-21, max=21 },
        {id="magicalSkillBoost",    min=-55, max=65 },
        {id="healSkillBoost",       min=  1, max=35 },
        {id="critical",             min=  1, max=30 },
        {id="magicalCritical",      min=  0, max=10 },
        {id="hitAccuracy",          min=  1, max=40 },
        {id="magicalHitAccuracy",   min=  0, max=20 },
        {id="attackDelay",          min=  0, max=19 },
        {id="boostCastingTime",     min= -9, max= 3 },
        {id="paralyze_arp",         min= -8, max=19 },
        {id="silence_arp",          min=-15, max=12 },
    },
    defensive = {
        {id="physicalDefend",            min=  2, max= 50 },
        {id="magicalResist",             min=  1, max= 15 },
        {id="magicalSkillBoostResist",   min=  1, max= 20 },
        {id="block",                     min=-145, max=119 },
        {id="parry",                     min= -98, max=107 },
        {id="dodge",                     min= -53, max= 10 },
        {id="maxHp",                     min=-347, max=109 },
        {id="maxMp",                     min= -50, max=245 },
    },
    resist = {
        {id="arParalyze", min=-6, max=3 },
        {id="arSilence",  min= 3, max=9 },
    },
    utility = {
        {id="speed", min=1, max=2 },
    },
}

-- tier_config: 每 tier 决定槽数 + 允许的 category 集合（与 v0 同结构）
entropy.random_attr_tier_config = {
    common = { slots = 4,  categories = {"offensive", "defensive"} },
    rare   = { slots = 7,  categories = {"offensive", "defensive", "resist"} },
    epic   = { slots = 10, categories = {"offensive", "defensive", "resist", "utility"} },
}

-- ============================================================
-- §2 — 12 × 4 偏置矩阵（class+race-aware，用户授权自定）
-- ============================================================

-- 矩阵格式: bias[class][category] = weight。用 category 级权重而不是
-- per-attr 权重，原因：(a) 23 attr × 12 class × 4 tier = 1100 cell 太琐碎，
-- 玩家也察觉不出 phyAttack 单独权重 vs critical 单独权重的区别；(b) category
-- 级偏置已能制造"warrior 偏物攻 / mage 偏魔攻"的明显 feel — 这才是
-- "明显是 X 职业的剑"信号。
--
-- 默认权重含义: offensive/defensive/resist/utility = 相对权重。
--   1.0 = baseline; >1.0 = 偏好该 category; <1.0 = 抑制
--
-- 覆盖了 3 原型 (Gladiator / Sorcerer / Cleric)；其它 9 职业用 default。
-- Cycle 17 起按玩家反馈逐步细化。
entropy.bias_matrix = {
    -- 战士系: 物攻爆击为主，少 utility
    Gladiator = {
        offensive = 1.6, defensive = 1.0, resist = 0.8, utility = 0.5,
    },
    -- 法师系: 魔攻 boost 为主，HP/防御抑制
    Sorcerer = {
        offensive = 1.6, defensive = 0.6, resist = 1.0, utility = 0.8,
    },
    -- 治疗系: 防御 + heal boost 为主
    Cleric = {
        offensive = 0.9, defensive = 1.5, resist = 1.2, utility = 1.0,
    },
    -- 兜底: 所有 category 等权 1.0
    default = {
        offensive = 1.0, defensive = 1.0, resist = 1.0, utility = 1.0,
    },
}

-- race_bias[race][attr_id] = 乘数 (作用于该 attr 被选中后的权重)
-- Elyos (1) 略偏魔法导向; Asmodian (2) 略偏物理导向 — 与 lore 相符。
-- 1.1 倍是"轻微但统计可检测"的程度，1000 次抽样能出 ~10% 比例差距。
entropy.race_attr_bias = {
    [1] = { magicalSkillBoost = 1.10, magicalAttack = 1.05 },  -- Elyos
    [2] = { phyAttack = 1.10, critical = 1.05 },               -- Asmodian
}

-- ============================================================
-- §3 — LCG PRNG（与 v0 同核心，但 stream_id != 0 派生子流）
-- ============================================================
-- 注意：跟 manastone_roll.lua 是相同算法，但是为避免循环依赖把它复制了一份。
-- 两个文件都 hot-reload 时各自独立，没有维护负担问题。

local LCG_MUL = 1664525
local LCG_ADD = 1013904223
local LCG_MOD = 2147483648  -- 2^31

local function lcg_next(state)
    local s = (state * LCG_MUL + LCG_ADD) % LCG_MOD
    return s, s / LCG_MOD
end

-- derive_subseed: stream_id 让 v1 与 v0 manastone 派生独立 LCG 流。
-- §3.2 设计文档已证明为什么不能复用 v0 状态（统计相关性 → 玩家 spot pattern）。
local function derive_subseed(item_id, count, race, season_seed, stream_id)
    local g = 2654435761  -- 黄金分割比素数 (Knuth)
    local h = 2246822519  -- 第二良好分布素数
    local k = 134775813   -- Borland C 经典常数
    local s = ((item_id     * g) % LCG_MOD
            +  (count       * h) % LCG_MOD
            +  ((race or 0) * k) % LCG_MOD
            +  (season_seed or 0)
            +  (stream_id   * 31337)) % LCG_MOD
    return (s * LCG_MUL + LCG_ADD) % LCG_MOD  -- 一次 LCG 迭代作为 mix
end

-- ============================================================
-- §4 — 不放回加权抽样
-- ============================================================

-- weighted_pick: 从 candidates 列表按权重抽 1 个（不放回 — 调用方需移除）
-- 返回 idx (在 candidates 中的索引) + 新 LCG state
local function weighted_pick(state, candidates)
    local total = 0
    for i = 1, #candidates do
        total = total + candidates[i].weight
    end
    if total <= 0 then return state, nil end

    local s2, r = lcg_next(state)
    local pick = r * total
    local acc = 0
    for i = 1, #candidates do
        acc = acc + candidates[i].weight
        if pick < acc then
            return s2, i
        end
    end
    return s2, #candidates  -- 浮点尾部安全网
end

-- ============================================================
-- §5 — 主滚动函数
-- ============================================================

-- entropy.roll_random_attrs(item_id, count, item_class, tier, race, season_seed)
--   -> array of {attr_id=string, value=number}, length 0..10
function entropy.roll_random_attrs(item_id, count, item_class, tier, race, season_seed)
    item_id     = tonumber(item_id)     or 0
    count       = tonumber(count)       or 1
    season_seed = tonumber(season_seed) or 0
    race        = tonumber(race)        or 0
    item_class  = item_class or "default"
    tier        = tier       or "common"

    local cfg = entropy.random_attr_tier_config[tier]
    if not cfg then return {} end

    local class_bias = entropy.bias_matrix[item_class] or entropy.bias_matrix.default
    local race_bias  = entropy.race_attr_bias[race] or {}

    -- 构造候选池: 把所有允许的 category 下的 attr 展开成单个列表，
    -- 每个 entry 携带 (id, min, max, weight = class_weight * race_multiplier)
    local candidates = {}
    for _, cat in ipairs(cfg.categories) do
        local cat_w = class_bias[cat] or 1.0
        local pool = entropy.random_attr_pool[cat] or {}
        for _, attr in ipairs(pool) do
            local race_mul = race_bias[attr.id] or 1.0
            candidates[#candidates + 1] = {
                id = attr.id, min = attr.min, max = attr.max,
                weight = cat_w * race_mul,
            }
        end
    end

    -- Round 8 C6 — v3 季节池：在 attr value 计算后乘 pool.attr_bias[attr_id]。
    -- 注意：池影响 value 而不影响 weight (权重)，因为：
    --   (a) 影响 weight 会与 v1 class+race bias 三层叠乘，难以做卡方诊断
    --   (b) 影响 value 是"每件装备 attr 强度的全服 modifier"，语义清晰
    --   (c) value 仍 clamp 到 [min, max]，避免溢出 NCSoft 客户端的 attr 显示位
    local active_pool = entropy.season_pool and
        entropy.season_pool.active_pool(season_seed) or nil

    -- 不放回抽 N 个: 用主流派生 + per-slot 子流（每 slot 独立 stream_id 防关联）
    local result = {}
    local n = math.min(cfg.slots, #candidates)
    for slot = 1, n do
        local state = derive_subseed(item_id, count, race, season_seed, slot)
        local _, idx = weighted_pick(state, candidates)
        if not idx then break end

        local chosen = candidates[idx]
        -- 在 [min, max] 内用同一 PRNG 滚一个值
        local _, r = lcg_next(state)
        local span = chosen.max - chosen.min
        local value = chosen.min + math.floor(r * (span + 1))
        if value > chosen.max then value = chosen.max end  -- r==1.0 边界保护

        -- v3 季节池修饰 + clamp 回 [min, max]（防止 lucky_seven 的 1.05 把
        -- max=20 推到 21 触发客户端校验）
        if active_pool then
            value = entropy.season_pool.apply_to_attr(value, chosen.id, active_pool)
            if value > chosen.max then value = chosen.max end
            if value < chosen.min then value = chosen.min end
        end

        result[#result + 1] = { attr_id = chosen.id, value = value }

        -- 不放回: O(n) remove，n ≤ 23 故无所谓
        table.remove(candidates, idx)
    end

    return result
end

-- ============================================================
-- §6 — Bridge wrapper（对应 player.add_item_with_random_attr）
-- ============================================================

-- entropy.add_item_with_random_attr — 单点集成函数。
-- 跟 v0 add_item_with_stones 同样的签名风格 + 容错默认。
function entropy.add_item_with_random_attr(gw, item_id, count,
                                            item_class, tier, race, season_seed)
    item_class  = item_class  or "default"
    tier        = tier        or "common"
    race        = tonumber(race) or 0
    season_seed = tonumber(season_seed) or 0

    local attrs = entropy.roll_random_attrs(
        item_id, count, item_class, tier, race, season_seed)

    -- Round 7 C5: 算 forge ID + 检测 synergy，仅 log（持久化等 v3 SP 落地）。
    -- 即使 Go bridge 不在（理论不可能但防御性），forge_id/detect_synergy 也
    -- 返回稳定占位值，不影响 grant 路径。
    if entropy.forge_id then
        local forge_id = entropy.forge_id({
            item_id = item_id, count = count, race = race,
            season_seed = season_seed, stones = {}, attrs = attrs,
        })
        local synergies = entropy.detect_synergy and
            entropy.detect_synergy({}, attrs) or {}
        if log and log.info then
            log.info(string.format(
                "[forge] random_attr iid=%d cnt=%d cls=%s tier=%s race=%d -> %s synergy=%s",
                tonumber(item_id) or 0, tonumber(count) or 1,
                tostring(item_class), tostring(tier), tonumber(race) or 0,
                forge_id,
                entropy.summarize_synergies and
                    entropy.summarize_synergies(synergies) or "(?)"))
        end
    end

    -- 调用 bridge stub。Round 6 阶段 stub 只 log + 走 legacy SP，
    -- B 轨提供 aion_AddItemUserWithRandomAttr 后再 INSERT user_item_attribute。
    player.add_item_with_random_attr(gw, item_id, count,
        item_class, tier, race, season_seed, attrs)
end

-- 自检: load 时 roll 一次确认无 panic。
do
    local probe = entropy.roll_random_attrs(100000001, 1, "Gladiator", "common", 2, 12345)
    assert(type(probe) == "table",
        "entropy.roll_random_attrs must return a table")
end
