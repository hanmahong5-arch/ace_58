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
            player.add_item(gw, 100000001, 1)  -- Starter Sword
            player.add_item(gw, 110000001, 1)  -- Starter Armour
        end
        log.info("quest 10001: rewards granted entity_id=" .. tostring(entity_id))
        -- TODO Phase S-5: grant EXP via db.call("aion_AddExpUser", char_id, amount).
    end,
})
