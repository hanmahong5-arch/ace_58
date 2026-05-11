-- scripts/quests/quest_10001.lua
-- Quest: "A New Beginning" — starter quest for new characters.
--
-- Steps:
--   1. Talk to the Guardian of Sanctum (NPC stub for Phase S-4).
--   2. Collect 3 Aether Crystals (item_id 182400001).
--
-- Rewards:
--   Starter sword (item_id 100000001, count 1)
--   Starter armour (item_id 110000001, count 1)

quest.register({
    id    = 10001,
    name  = "A New Beginning",
    steps = 2,

    on_start = function(entity_id)
        log.info("quest 10001: started for entity_id=" .. tostring(entity_id))
        -- TODO Phase S-5: send SM_QUEST_INFO packet to show quest journal entry.
    end,

    on_complete = function(entity_id)
        -- Round 11 A8 (patch 01): 升级到 entropy v1 random_attr。
        -- rare tier (7 槽) 让新手"第一件装备"就感受词缀差异 — 同 class 的
        -- 两个玩家拿到的剑词缀向量不同, 是高熵命题的"第一印象证明"。
        -- TODO Cycle 17+: 待 entropy.add_item_full(stones+attrs) 落地后,
        --                同时挂 v0 (5 manastone) + v1 (7 random_attr) — 见
        --                doc/entropy/wiring-patches/01-quest_10001-add-v1-random-attr.patch。
        local gw = entity.get_gateway_id(entity_id)
        if gw then
            local class_name = class_names and
                class_names.of_entity(entity_id) or "default"
            local race       = entity.get_stat(entity_id, "faction") or 0
            local seed       = season_seed()
            entropy.add_item_with_random_attr(gw, 100000001, 1,
                class_name, "rare", race, seed)  -- Starter Sword
            entropy.add_item_with_random_attr(gw, 110000001, 1,
                class_name, "rare", race, seed)  -- Starter Armour
        end
        log.info("quest 10001: rewards granted entity_id=" .. tostring(entity_id))
        -- TODO Phase S-5: grant EXP via db.call("aion_AddExpUser", char_id, amount).
    end,
})
