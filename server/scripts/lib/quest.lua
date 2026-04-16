-- scripts/lib/quest.lua
-- Quest registry and state-machine framework.
--
-- Quest state is stored in ECS stats using the key "quest_<id>_state":
--   0  = not started / completed (cleared after completion)
--   1  = accepted (in progress, step 1)
--   N  = in progress at step N
--   99 = ready to turn in
--
-- Usage:
--   quest.register({ id=10001, name="...", on_start=fn, on_complete=fn, steps={...} })
--   quest.start(entity_id, quest_id)       -- begin the quest
--   quest.advance(entity_id, quest_id, N)  -- move to step N
--   quest.complete(entity_id, quest_id)    -- finish and award rewards
--   quest.state(entity_id, quest_id)       -- query current step (0 if not active)

quest = {}

-- Internal registry: quest definitions keyed by quest ID.
local _registry = {}

-- --------------------------------------------------------
-- quest.register(def): declare a quest definition.
-- def fields:
--   id          (number, required) unique quest identifier
--   name        (string) display name
--   steps       (number, optional) total number of objectives; default 1
--   on_start    (function, optional) called with entity_id when quest begins
--   on_complete (function, optional) called with entity_id on completion
-- --------------------------------------------------------
quest.register = function(def)
    if not def or not def.id then
        log.warn("quest.register: missing id in definition")
        return
    end
    _registry[def.id] = def
end

-- --------------------------------------------------------
-- quest.start(entity_id, quest_id) -> bool
-- Accepts a quest for the given entity.  Returns false if already active.
-- --------------------------------------------------------
quest.start = function(entity_id, quest_id)
    local def = _registry[quest_id]
    if not def then
        log.warn("quest.start: unknown quest_id=" .. tostring(quest_id))
        return false
    end
    local state_key = "quest_" .. quest_id .. "_state"
    if entity.get_stat(entity_id, state_key) > 0 then
        return false  -- already active
    end
    entity.set_stat(entity_id, state_key, 1)
    if def.on_start then
        def.on_start(entity_id)
    end
    log.info("quest: started quest_id=" .. tostring(quest_id)
        .. " entity_id=" .. tostring(entity_id))
    return true
end

-- --------------------------------------------------------
-- quest.advance(entity_id, quest_id, step) -> bool
-- Advances the quest to the given step number.
-- --------------------------------------------------------
quest.advance = function(entity_id, quest_id, step)
    local state_key = "quest_" .. quest_id .. "_state"
    if entity.get_stat(entity_id, state_key) == 0 then
        return false  -- not active
    end
    entity.set_stat(entity_id, state_key, step)
    return true
end

-- --------------------------------------------------------
-- quest.complete(entity_id, quest_id) -> bool
-- Completes the quest, fires on_complete callback, and clears state.
-- --------------------------------------------------------
quest.complete = function(entity_id, quest_id)
    local def = _registry[quest_id]
    if not def then
        return false
    end
    local state_key = "quest_" .. quest_id .. "_state"
    entity.set_stat(entity_id, state_key, 0)
    if def.on_complete then
        def.on_complete(entity_id)
    end
    log.info("quest: completed quest_id=" .. tostring(quest_id)
        .. " entity_id=" .. tostring(entity_id))
    return true
end

-- --------------------------------------------------------
-- quest.state(entity_id, quest_id) -> number
-- Returns the current step (0 = not active / not started).
-- --------------------------------------------------------
quest.state = function(entity_id, quest_id)
    return entity.get_stat(entity_id, "quest_" .. quest_id .. "_state")
end
