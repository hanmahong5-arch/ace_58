-- AionCore 5.8 — 3-parameter convenience wrapper over aion_PutItem_20150921.
--
-- No NCSoft equivalent. NCSoft only ships the 41-param `aion_PutItem_20150921`
-- (full item record with skin / enchant / soul-bound / 6 stat-enchants / etc).
-- Runtime callers granting starter gear, quest rewards, or system-mail loot
-- want a "create a clean stock item" entry point — passing 38 zeros every
-- time is noise, hides typos, and spreads the default-value contract across
-- many caller files.
--
-- Used by:
--   scripts/lib/starter_kit.lua   -- new-char gear grant after PutChar
--   scripts/lib/api.lua            -- player.add_item(gw, id, count) docs
--                                     this as the underlying SP
--
-- This wrapper just routes to aion_putitem_20150921 with default zeros for
-- the cosmetic / enchant / option columns. The heavy SP is still the single
-- source of truth for the user_item INSERT; this is a parameter-count facade.
--
-- Returns the new user_item.id (BIGINT) on success, matching aion_putitem.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_additemuser(INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_additemuser(
    _char_id  INTEGER,
    _item_id  INTEGER,   -- becomes name_id; 'item_id' is the Lua naming
    _count    BIGINT     -- becomes amount; default 1 if caller passes <= 0
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _amt BIGINT;
BEGIN
    -- Defensive default: callers occasionally pass count=0 from defaulted
    -- table fields (e.g. quest reward with no explicit count). One item is
    -- the principle of least surprise vs. inserting an amount=0 ghost row.
    _amt := GREATEST(_count, 1);

    -- Delegate to the heavy SP. Position-args mirror its parameter list;
    -- everything past _amount is a stock zero (no skin/enchant/soul/etc).
    -- _slot_num=0 means "next free slot" per NCSoft convention; the engine
    -- assigns inventory_slot at first GetItemList read.
    RETURN aion_putitem_20150921(
        _char_id,        -- _char_id
        _item_id,        -- _name_id
        0,               -- _slot_id
        _amt,            -- _amount
        0::BIGINT,       -- _tid
        0,               -- _slot_num
        0,               -- _warehouse (0 = inventory)
        0,               -- _soul_bound
        0,               -- _enchant_count
        0,               -- _skin_name_id
        0, 0, 0, 0, 0, 0,  -- _stat_enchant_name 0..5
        0,               -- _option_count
        0,               -- _dye_info
        0,               -- _proc_tool_nameid
        0,               -- _expired_time
        '',              -- _producer
        0,               -- _buy_amount
        0,               -- _buy_duration
        0,               -- _obtain_skin_type
        0,               -- _expire_skin_time
        0,               -- _dynamic_property
        1,               -- _server_of_origin (1 = home shard)
        0,               -- _expire_dye_time
        0,               -- _random_option
        0,               -- _limit_enchant_count
        0,               -- _reidentify_count
        0,               -- _authorize_count
        0,               -- _vanish_point
        0,               -- _enchant_prob_addition
        0,               -- _option_prob_addition
        0,               -- _key_name_id
        0,               -- _exceed_state
        0, 0, 0,         -- _exceed_skill_id 1..3
        0,               -- _base_skill_id
        0,               -- _enhance_skill_group
        0                -- _enhance_skill_level
    );
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_additemuser(INTEGER, INTEGER, BIGINT);
-- +goose StatementEnd
