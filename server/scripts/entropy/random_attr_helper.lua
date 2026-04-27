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
-- Round 9 C7: 新增 legendary tier (12 槽), 与 epic 共享 categories；
-- 短期 bridge 仍走 legacy SP, 待 SP `aion_AddItemUserWithRandomAttr` 落地后
-- legendary 才走专用持久化路径（持 attr 数升至 12）。
entropy.random_attr_tier_config = {
    common    = { slots = 4,  categories = {"offensive", "defensive"} },
    rare      = { slots = 7,  categories = {"offensive", "defensive", "resist"} },
    epic      = { slots = 10, categories = {"offensive", "defensive", "resist", "utility"} },
    legendary = { slots = 12, categories = {"offensive", "defensive", "resist", "utility"} },
}

-- ============================================================
-- §2 — 12 × 4 偏置矩阵 (Round 9 C7: per-attr × per-tier 升级)
-- ============================================================
--
-- Round 9 C7 把矩阵从 4-category 权重升级为 per-attr × per-tier 字典。
-- 原因: category 级偏置只能让玩家分辨 "warrior vs mage"，分不出
-- "phyAttack 重武 vs critical 重武"。new spec 让 12 职业每 tier 各有
-- 一组主属性 (25-35) / 次要 (15-22) / 杂项 (5-10) / baseline (1)，
-- 玩家凭 attr 一眼能认出"这是 X 职业的剑"。
--
-- 设计原则 (详见 doc/entropy/class-bias-design.md §4):
--   1. 主属性 1-2 个 / 25-35 权重；次要 3-5 个 / 15-22；杂项 2-4 个 / 5-10
--   2. 未列出的 attr_id 隐式 baseline weight = 1（保抽样池非空 + 偶发奇葩 attr）
--   3. 每 tier 总和 ~100 (容差 ±5)
--   4. 低 tier 主属性更集中，高 tier 略下放权重多样性递增
--   5. legendary tier 与 epic 接近但更两极 (主更主、副更副)
--   6. race_attr_bias / season_pool 修饰 layer 不变（race 改 weight，
--      season 改 value，避免三层叠乘）
--
-- 数据格式:
--   bias_matrix[ClassName][tier_name] = { attr_id = weight_number, ... }
--   bias_matrix.default[tier_name]   = nil  -- 直接 fall through 到 baseline=1

entropy.bias_matrix = {
    -- ============= 战士系 =============
    -- Gladiator — 物理双手近战 + 防反混合
    Gladiator = {
        common    = { phyAttack=30, physicalDefend=20, maxHp=15, critical=15, hitAccuracy=10, parry=5, block=5 },
        rare      = { phyAttack=28, critical=15, physicalDefend=15, maxHp=10, parry=10, hitAccuracy=10, attackDelay=7, paralyze_arp=5 },
        epic      = { phyAttack=25, critical=15, physicalDefend=12, maxHp=10, parry=10, hitAccuracy=8, attackDelay=8, paralyze_arp=7, speed=5 },
        legendary = { phyAttack=22, critical=15, physicalDefend=12, maxHp=10, attackDelay=10, parry=10, hitAccuracy=8, paralyze_arp=8, speed=5 },
    },
    -- Templar — 重盾坦克 + 嘲讽
    Templar = {
        common    = { physicalDefend=30, maxHp=25, block=15, parry=10, magicalResist=10, phyAttack=10 },
        rare      = { physicalDefend=25, maxHp=20, block=15, parry=10, magicalResist=10, magicalSkillBoostResist=10, phyAttack=5, arParalyze=5 },
        epic      = { physicalDefend=22, maxHp=18, block=15, parry=10, magicalResist=10, magicalSkillBoostResist=10, arParalyze=8, arSilence=7 },
        legendary = { physicalDefend=22, maxHp=18, block=15, parry=10, magicalResist=10, magicalSkillBoostResist=10, arParalyze=8, arSilence=5, speed=2 },
    },

    -- ============= 侦察系 =============
    -- Assassin — 物理 burst + 高命中
    Assassin = {
        common    = { phyAttack=30, critical=25, hitAccuracy=15, attackDelay=10, dodge=10, maxHp=10 },
        rare      = { phyAttack=28, critical=20, hitAccuracy=15, attackDelay=12, paralyze_arp=10, dodge=10, maxHp=5 },
        epic      = { phyAttack=25, critical=20, hitAccuracy=12, attackDelay=12, paralyze_arp=10, dodge=10, silence_arp=6, speed=5 },
        legendary = { phyAttack=25, critical=22, hitAccuracy=12, attackDelay=12, paralyze_arp=10, dodge=8, silence_arp=6, speed=5 },
    },
    -- Ranger — 物理远程 + 风筝
    Ranger = {
        common    = { phyAttack=28, hitAccuracy=22, attackDelay=15, critical=15, dodge=10, maxHp=10 },
        rare      = { phyAttack=25, hitAccuracy=20, attackDelay=15, critical=15, paralyze_arp=10, dodge=8, speed=7 },
        epic      = { phyAttack=22, hitAccuracy=18, attackDelay=15, critical=15, paralyze_arp=10, dodge=8, speed=7, silence_arp=5 },
        legendary = { phyAttack=22, hitAccuracy=18, attackDelay=15, critical=15, paralyze_arp=10, speed=8, dodge=7, silence_arp=5 },
    },

    -- ============= 法师系 =============
    -- Sorcerer — 魔攻爆发 + AoE
    -- 设计选择: magicalAttack 是主属性 (28-30), magicalSkillBoost 作次要 (12-15)。
    -- 真实游戏里 Sorcerer 也是 magic atk + crit > magic boost (boost 偏向 SM/SW)。
    -- 副效益: magicalSkillBoost 不再 ceiling, race_bias × 1.25 在 1000 抽样能稳定
    -- 拉开 Elyos vs Asmodian 差距（race bias test 通过的前提）。
    Sorcerer = {
        common    = { magicalAttack=30, magicalCritical=20, magicalSkillBoost=15, magicalHitAccuracy=12, maxMp=12, boostCastingTime=11 },
        rare      = { magicalAttack=28, magicalCritical=18, magicalSkillBoost=15, magicalHitAccuracy=12, boostCastingTime=10, maxMp=8, silence_arp=9 },
        epic      = { magicalAttack=25, magicalCritical=18, magicalSkillBoost=15, magicalHitAccuracy=10, boostCastingTime=10, maxMp=7, silence_arp=10, speed=5 },
        legendary = { magicalAttack=25, magicalCritical=18, magicalSkillBoost=15, boostCastingTime=12, magicalHitAccuracy=10, maxMp=7, silence_arp=8, speed=5 },
    },
    -- Spiritmaster — 宠物 + DoT
    Spiritmaster = {
        common    = { magicalSkillBoost=28, magicalAttack=22, maxMp=18, magicalHitAccuracy=15, boostCastingTime=10, silence_arp=7 },
        rare      = { magicalSkillBoost=25, magicalAttack=20, maxMp=15, magicalHitAccuracy=12, boostCastingTime=10, silence_arp=10, magicalCritical=8 },
        epic      = { magicalSkillBoost=22, magicalAttack=18, maxMp=15, magicalHitAccuracy=10, boostCastingTime=10, silence_arp=10, magicalCritical=8, arSilence=7 },
        legendary = { magicalSkillBoost=22, magicalAttack=18, maxMp=15, magicalHitAccuracy=10, boostCastingTime=10, silence_arp=10, magicalCritical=8, arSilence=7 },
    },

    -- ============= 治疗系 =============
    -- Cleric — 主奶 + 生存防御
    Cleric = {
        common    = { healSkillBoost=28, magicalResist=18, magicalSkillBoostResist=15, maxHp=15, maxMp=12, magicalSkillBoost=12 },
        rare      = { healSkillBoost=25, magicalResist=15, magicalSkillBoostResist=15, maxHp=12, maxMp=10, magicalSkillBoost=10, arParalyze=8, arSilence=5 },
        epic      = { healSkillBoost=22, magicalResist=15, magicalSkillBoostResist=15, maxHp=12, magicalSkillBoost=10, maxMp=8, arParalyze=8, arSilence=5, speed=5 },
        legendary = { healSkillBoost=22, magicalResist=15, magicalSkillBoostResist=15, maxHp=12, magicalSkillBoost=10, maxMp=8, arParalyze=8, arSilence=5, speed=5 },
    },
    -- Chanter — 辅助 buff + 物理混合
    Chanter = {
        common    = { healSkillBoost=22, phyAttack=20, maxHp=18, magicalSkillBoost=12, hitAccuracy=10, magicalResist=10, maxMp=8 },
        rare      = { healSkillBoost=20, phyAttack=18, maxHp=15, magicalSkillBoost=12, hitAccuracy=10, magicalResist=10, magicalSkillBoostResist=8, critical=7 },
        epic      = { healSkillBoost=18, phyAttack=18, maxHp=12, magicalSkillBoost=12, hitAccuracy=10, magicalResist=10, magicalSkillBoostResist=8, critical=7, speed=5 },
        legendary = { healSkillBoost=18, phyAttack=18, maxHp=12, magicalSkillBoost=12, hitAccuracy=10, magicalResist=10, magicalSkillBoostResist=8, critical=7, speed=5 },
    },

    -- ============= 5.x 工程系 =============
    -- Aethertech — 重型机甲 + 远程物理
    Aethertech = {
        common    = { phyAttack=28, hitAccuracy=18, maxHp=18, physicalDefend=15, critical=12, attackDelay=9 },
        rare      = { phyAttack=25, hitAccuracy=18, maxHp=15, physicalDefend=12, critical=10, attackDelay=10, paralyze_arp=5, dodge=5 },
        epic      = { phyAttack=22, hitAccuracy=15, maxHp=15, physicalDefend=12, critical=10, attackDelay=10, paralyze_arp=8, dodge=5, speed=3 },
        legendary = { phyAttack=22, hitAccuracy=15, maxHp=15, physicalDefend=12, critical=10, attackDelay=10, paralyze_arp=8, dodge=5, speed=3 },
    },
    -- Gunslinger — 双枪机动 + 多目标
    Gunslinger = {
        common    = { phyAttack=25, magicalAttack=18, attackDelay=18, critical=15, hitAccuracy=12, dodge=12 },
        rare      = { phyAttack=22, magicalAttack=15, attackDelay=18, critical=15, hitAccuracy=12, dodge=10, paralyze_arp=5, speed=3 },
        epic      = { phyAttack=20, magicalAttack=15, attackDelay=18, critical=15, hitAccuracy=10, dodge=10, paralyze_arp=7, silence_arp=3, speed=2 },
        legendary = { phyAttack=20, magicalAttack=15, attackDelay=18, critical=15, hitAccuracy=10, dodge=10, paralyze_arp=7, silence_arp=3, speed=2 },
    },

    -- ============= 5.x 巫师系 =============
    -- Songweaver — 远程魔法 + 控场 buff
    Songweaver = {
        common    = { magicalAttack=25, magicalSkillBoost=22, healSkillBoost=15, magicalCritical=12, magicalHitAccuracy=12, boostCastingTime=10, maxMp=4 },
        rare      = { magicalAttack=22, magicalSkillBoost=20, healSkillBoost=12, magicalCritical=12, magicalHitAccuracy=10, boostCastingTime=10, silence_arp=10, maxMp=4 },
        epic      = { magicalAttack=20, magicalSkillBoost=18, healSkillBoost=12, magicalCritical=10, magicalHitAccuracy=10, boostCastingTime=10, silence_arp=10, maxMp=5, speed=5 },
        legendary = { magicalAttack=20, magicalSkillBoost=18, healSkillBoost=12, magicalCritical=10, magicalHitAccuracy=10, boostCastingTime=10, silence_arp=10, maxMp=5, speed=5 },
    },
    -- Bard (4.5+) — 团 buff/debuff + 治疗副
    Bard = {
        common    = { magicalSkillBoost=25, healSkillBoost=22, maxMp=18, maxHp=12, magicalResist=12, magicalCritical=11 },
        rare      = { magicalSkillBoost=22, healSkillBoost=20, maxMp=15, maxHp=12, magicalResist=10, magicalCritical=10, magicalSkillBoostResist=8, silence_arp=3 },
        epic      = { magicalSkillBoost=20, healSkillBoost=20, maxMp=15, maxHp=10, magicalResist=10, magicalCritical=8, magicalSkillBoostResist=8, silence_arp=5, speed=4 },
        legendary = { magicalSkillBoost=20, healSkillBoost=20, maxMp=15, maxHp=10, magicalResist=10, magicalCritical=8, magicalSkillBoostResist=8, silence_arp=5, speed=4 },
    },

    -- ============= Fallback =============
    -- default: 所有 attr 隐式 baseline=1, 不显式列出。未知职业自然走 baseline。
    default = {
        common    = {},
        rare      = {},
        epic      = {},
        legendary = {},
    },
}

-- BIAS_BASELINE: 未在 bias_matrix[class][tier] 中显式列出的 attr 隐式权重。
-- 必须 > 0；否则候选池可能空。1.0 = 与显式权重 100 总和接近 23 attr × 1 = 23
-- 比例约 1:5（主属性 25 vs baseline 1），既保多样性又突出主属性。
local BIAS_BASELINE = 1.0

-- race_bias[race][attr_id] = 乘数 (作用于该 attr 被选中后的权重)
-- Elyos (1) 略偏魔法导向; Asmodian (2) 略偏物理导向 — 与 lore 相符。
--
-- Round 9 C7 调参: 1.10 → 1.25, 1.05 → 1.15。
-- 原因: Round 6 设定 1.10 是相对 4-category bias（每 cat 1.0-1.6 区间）;
-- C7 升级到 per-attr bias 后, 主属性权重从 25-35 起跳, race 1.10 在
-- "不放回 7 槽 / 18 attr" 抽样下被 ceiling 抹平（两阵营都 ~100%）。
-- 1.25 / 1.15 在 1000 抽样能稳定拉开 5-10pp 差距, 仍属"轻微"。
entropy.race_attr_bias = {
    [1] = { magicalSkillBoost = 1.25, magicalAttack = 1.15 },  -- Elyos
    [2] = { phyAttack = 1.25, critical = 1.15 },               -- Asmodian
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

    -- Round 9 C7: 12 职业 + default fallback。新格式 bias_matrix[class][tier] 是
    -- {attr_id = weight} 字典；未列出的 attr 隐式 BIAS_BASELINE。
    -- 未知职业 (e.g. "Inquisitor") fallback 到 default，与 default 行为完全一致。
    local class_table = entropy.bias_matrix[item_class] or entropy.bias_matrix.default
    local tier_bias   = (class_table and class_table[tier]) or {}
    local race_bias   = entropy.race_attr_bias[race] or {}

    -- 构造候选池: 把所有允许的 category 下的 attr 展开成单个列表，每个 entry
    -- 携带 (id, min, max, weight = tier_attr_weight * race_multiplier)。
    -- 字典查找 O(1) — 23 attr × class lookup 总成本 < 1µs，远小于 PRNG 调用。
    local candidates = {}
    for _, cat in ipairs(cfg.categories) do
        local pool = entropy.random_attr_pool[cat] or {}
        for _, attr in ipairs(pool) do
            local base_w = tier_bias[attr.id] or BIAS_BASELINE
            local race_mul = race_bias[attr.id] or 1.0
            candidates[#candidates + 1] = {
                id = attr.id, min = attr.min, max = attr.max,
                weight = base_w * race_mul,
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
