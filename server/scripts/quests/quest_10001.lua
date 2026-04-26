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
        -- Award starter gear via player.add_item.
        local gw = entity.get_gateway_id(entity_id)
        if gw then
            -- Round 6 C4 — entropy v0 wiring: 新手剧情奖励是"第一印象"装备，
            -- 按 rare tier 放 5 槽 manastone，让新玩家立刻感受到"哇这把剑有 5 颗石"。
            entropy.add_item_with_stones(gw, 100000001, 1, "weapon", "rare", season_seed())  -- Starter Sword
            entropy.add_item_with_stones(gw, 110000001, 1, "armor",  "rare", season_seed())  -- Starter Armour
        end
        log.info("quest 10001: rewards granted entity_id=" .. tostring(entity_id))
        -- TODO Phase S-5: grant EXP via db.call("aion_AddExpUser", char_id, amount).
    end,
})
