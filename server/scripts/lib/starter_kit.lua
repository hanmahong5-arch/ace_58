-- scripts/lib/starter_kit.lua
-- Round 11 A8 — patch 10: 创角 starter 装备 entropy mint 集中表。
--
-- 设计意图: 玩家创角后第一次进入世界, 立刻获得带 random_attr 词缀的
-- starter 装备。这是高熵命题对新玩家的"第一印象 minute" — 创角即遇 RNG,
-- 杜绝 "前 30 分钟玩裸身" 的传统体验。NCSoft SP `aion_putchar_20160620`
-- 是否在内部 auto-grant starter 待 47104-sp-dump 校验 — 若已 grant,
-- 本文件改成 "BONUS" 模式 (额外送一件高词缀礼包) 而不是 "ONLY" 模式。
--
-- API:
--   starter_kit.grant_for_new_char(char_id, race, class_id) -> n_granted
--     在创角 SP 成功返回新 char_id 之后调用。当前实现走 db.call 直接打
--     SP `aion_AddItemUser` (char_id-based, 不需要 gateway_seq_id), 因为
--     角色尚未 select, 没有 entity / gw 绑定。stones/attrs 等持久化需
--     Track B3 升级 SP — 本 round 仅 grant + LOG entropy 意图 (forge_id)。
--
-- 设计约束:
--   * 不调用 entropy.add_item_with_random_attr (需要 gw, 创角阶段没有);
--     待 bridge.go 提供 entropy.mint_for_charid 后改造。
--   * starter 物品按职业差异化 (Gladiator 双手剑 / Sorcerer 法杖 / ...) —
--     NCSoft 5.8 starter 装备 ID 表来自 client_pak PC/class_data.xml,
--     此处用占位 ID, Cycle 17 NCSoft data import 后替换。
--   * race 影响 starter 装备外观 (Elyos 白甲 / Asmodian 黑甲), 但 5.8
--     初版默认走 race-agnostic ID, race 仅做 LOG 备注。

starter_kit = starter_kit or {}

-- ============================================================
-- §1 — 12 职业 starter 装备表 (item_id 按 class_id 索引)
-- ============================================================
--
-- 字段: weapon (主手) / armor (上装) — MVP 只发 2 件, 按 entropy v1 rare
-- tier (7 random_attr) 锻造。后续可加 helm/gloves/boots 等扩到完整 6 件套。

starter_kit.kits_by_class = {
    -- Gladiator: 双手剑 + 重甲
    [0]  = { weapon = 100000001, armor = 110000001 },
    -- Templar: 单手剑+盾 → 盾归 sub_hand 暂未发, 仅 weapon+armor
    [1]  = { weapon = 100000011, armor = 110000011 },
    -- Assassin: 双匕 (主匕)
    [2]  = { weapon = 100000021, armor = 110000021 },
    -- Ranger: 弓 + 皮甲
    [3]  = { weapon = 100000031, armor = 110000031 },
    -- Sorcerer: 法杖 + 法袍
    [4]  = { weapon = 100000041, armor = 110000041 },
    -- Spiritmaster: 法球 + 法袍
    [5]  = { weapon = 100000051, armor = 110000051 },
    -- Cleric: 锤子 + 锁链甲
    [6]  = { weapon = 100000061, armor = 110000061 },
    -- Chanter: 长棍 + 锁链甲
    [7]  = { weapon = 100000071, armor = 110000071 },
    -- Aethertech: 机甲枪 + 重甲
    [8]  = { weapon = 100000081, armor = 110000081 },
    -- Gunslinger: 双枪 + 皮甲
    [9]  = { weapon = 100000091, armor = 110000091 },
    -- Songweaver: 竖琴 + 法袍
    [10] = { weapon = 100000101, armor = 110000101 },
    -- Bard: 鲁特琴 + 法袍
    [11] = { weapon = 100000111, armor = 110000111 },
}

-- ============================================================
-- §2 — Grant 实现
-- ============================================================

-- starter_kit.grant_for_new_char(char_id, race, class_id) -> n_granted
-- 返回成功 grant 的物品数 (0..2)。失败不抛错, 仅 log warn — 创角主流程
-- 不应被 starter_kit 的次要失败阻断。
function starter_kit.grant_for_new_char(char_id, race, class_id)
    char_id  = tonumber(char_id)  or 0
    class_id = tonumber(class_id) or 0
    race     = tonumber(race)     or 0
    if char_id <= 0 then return 0 end
    if not db or not db.call then
        log.warn("starter_kit: db unavailable, skipping grant char_id=" .. tostring(char_id))
        return 0
    end

    local kit = starter_kit.kits_by_class[class_id]
    if not kit then
        log.warn("starter_kit: no kit for class_id=" .. tostring(class_id))
        return 0
    end

    -- entropy LOG: 创角时 forge_id 提前算出 (用 char_id 做 mix 保证唯一),
    -- 玩家进世界后 SM_INVENTORY_INFO 显示的就是这 2 件 starter; 群里晒图
    -- 时 forge_id 可作为 "我的开荒第一件" 永久编号。
    local class_name = (class_names and class_names.of(class_id)) or "default"
    local seed       = (entropy and entropy.season_seed and
                       entropy.season_seed()) or 0

    local n = 0
    for slot, item_id in pairs(kit) do
        local _, err = db.call("aion_AddItemUser", char_id, item_id, 1)
        if err then
            log.warn("starter_kit: grant failed slot=" .. tostring(slot)
                .. " iid=" .. tostring(item_id) .. " err=" .. tostring(err))
        else
            n = n + 1
            -- 占位 forge_id LOG (rare tier 7 attrs 期望; 真 attrs 待 SP B3)
            if entropy and entropy.forge_id then
                local fid = entropy.forge_id({
                    item_id = item_id, count = 1, race = race,
                    season_seed = seed, stones = {}, attrs = {},
                })
                log.info(string.format(
                    "[forge] starter_kit cid=%d iid=%d slot=%s cls=%s race=%d -> %s",
                    char_id, item_id, tostring(slot), class_name, race, fid))
            end
        end
    end
    return n
end

-- ============================================================
-- §3 — 自检
-- ============================================================
do
    -- 12 职业全部有 kit
    for cid = 0, 11 do
        assert(starter_kit.kits_by_class[cid],
            "starter_kit missing kit for class_id=" .. cid)
        assert(starter_kit.kits_by_class[cid].weapon,
            "starter_kit class_id=" .. cid .. " missing weapon")
        assert(starter_kit.kits_by_class[cid].armor,
            "starter_kit class_id=" .. cid .. " missing armor")
    end
end
