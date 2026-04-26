-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_SetItemEnchant_20180615.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetItemEnchant_20180615.sql
-- Upserts the option/enchant row for one user_item. T-SQL is an UPDATE-then-
-- INSERT-on-zero-rowcount-with-fallback-UPDATE; PG translation collapses to
-- INSERT … ON CONFLICT DO UPDATE which is atomic and race-free.
--
-- Special rule preserved from T-SQL:
--   if @enchantCount = 0 AND main_item_dbid > 0 → keep existing enchant_count
--   This handles the "secondary weapon" case where the client doesn't echo
--   the enchant and we must not zero it out.
--
-- All identifiers UNQUOTED so PG folds to lowercase, matching how 00008
-- created the user_item_option columns originally.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemenchant_20180615(
    BIGINT, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemenchant_20180615(
    _id                   BIGINT,
    _soul_bound           INTEGER,
    _enchant_count        INTEGER,
    _skin_name_id         INTEGER,
    _wardrobe_slot_id     INTEGER,
    _stat_enchant_name0   INTEGER,
    _stat_enchant_name1   INTEGER,
    _stat_enchant_name2   INTEGER,
    _stat_enchant_name3   INTEGER,
    _stat_enchant_name4   INTEGER,
    _stat_enchant_name5   INTEGER,
    _proc_tool_nameid     INTEGER,
    _obtain_skin_type     INTEGER,
    _expire_skin_time     INTEGER,
    _limit_enchant_count  INTEGER,
    _authorize_count      INTEGER,
    _vanish_point         INTEGER,
    _enchant_prob_addition INTEGER,
    _option_prob_addition INTEGER,
    _key_name_id          INTEGER,
    _exceed_state         INTEGER,
    _exceed_skill_id1     INTEGER,
    _exceed_skill_id2     INTEGER,
    _exceed_skill_id3     INTEGER,
    _base_skill_id        INTEGER,
    _enhance_skill_group  INTEGER,
    _enhance_skill_level  INTEGER,
    _equip_level_down     INTEGER,
    _random_attr1   INTEGER, _random_value1  INTEGER,
    _random_attr2   INTEGER, _random_value2  INTEGER,
    _random_attr3   INTEGER, _random_value3  INTEGER,
    _random_attr4   INTEGER, _random_value4  INTEGER,
    _random_attr5   INTEGER, _random_value5  INTEGER,
    _random_attr6   INTEGER, _random_value6  INTEGER,
    _random_attr7   INTEGER, _random_value7  INTEGER,
    _random_attr8   INTEGER, _random_value8  INTEGER,
    _random_attr9   INTEGER, _random_value9  INTEGER,
    _random_attr10  INTEGER, _random_value10 INTEGER,
    _skill_skin_name_id   INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    v_char_id        INTEGER;
    v_main_item_id   BIGINT;
    v_effective_ec   INTEGER := _enchant_count;
BEGIN
    -- T-SQL preserves enchant when secondary weapon comes through with EC=0.
    IF _enchant_count = 0 THEN
        SELECT COALESCE(main_item_dbid, 0) INTO v_main_item_id
          FROM user_item WHERE id = _id;
        IF v_main_item_id IS NOT NULL AND v_main_item_id > 0 THEN
            SELECT COALESCE(enchant_count, 0) INTO v_effective_ec
              FROM user_item_option WHERE id = _id;
            IF v_effective_ec IS NULL THEN
                v_effective_ec := 0;
            END IF;
        END IF;
    END IF;

    -- Look up char_id for the INSERT branch (NCSoft duplicates the col on
    -- _option for fast char-scope queries).
    SELECT char_id INTO v_char_id FROM user_item WHERE id = _id;

    INSERT INTO user_item_option (
        id, char_id,
        soul_bound, enchant_count, skin_name_id, wardrobeslotid,
        stat_enchant_name0, stat_enchant_name1, stat_enchant_name2,
        stat_enchant_name3, stat_enchant_name4, stat_enchant_name5,
        proc_tool_nameid, obtain_skin_type, expire_skin_time,
        limit_enchant_count, authorize_count, vanish_point,
        enchant_prob_addition, option_prob_addition,
        keynameid, exceedstate,
        exceedskillid1, exceedskillid2, exceedskillid3,
        baseskillid, enhanceskillgroup, enhanceskilllevel,
        equipleveldown,
        randomattr1, randomvalue1, randomattr2, randomvalue2,
        randomattr3, randomvalue3, randomattr4, randomvalue4,
        randomattr5, randomvalue5, randomattr6, randomvalue6,
        randomattr7, randomvalue7, randomattr8, randomvalue8,
        randomattr9, randomvalue9, randomattr10, randomvalue10,
        skill_skin_name_id
    ) VALUES (
        _id, COALESCE(v_char_id, 0),
        _soul_bound, v_effective_ec, _skin_name_id, _wardrobe_slot_id::SMALLINT,
        _stat_enchant_name0, _stat_enchant_name1, _stat_enchant_name2,
        _stat_enchant_name3, _stat_enchant_name4, _stat_enchant_name5,
        _proc_tool_nameid, _obtain_skin_type, _expire_skin_time,
        _limit_enchant_count, _authorize_count, _vanish_point,
        _enchant_prob_addition, _option_prob_addition,
        _key_name_id, _exceed_state,
        _exceed_skill_id1, _exceed_skill_id2, _exceed_skill_id3,
        _base_skill_id, _enhance_skill_group, _enhance_skill_level,
        _equip_level_down::SMALLINT,
        _random_attr1, _random_value1, _random_attr2, _random_value2,
        _random_attr3, _random_value3, _random_attr4, _random_value4,
        _random_attr5, _random_value5, _random_attr6, _random_value6,
        _random_attr7, _random_value7, _random_attr8, _random_value8,
        _random_attr9, _random_value9, _random_attr10, _random_value10,
        _skill_skin_name_id
    )
    ON CONFLICT (id) DO UPDATE SET
        soul_bound             = EXCLUDED.soul_bound,
        enchant_count          = EXCLUDED.enchant_count,
        skin_name_id           = EXCLUDED.skin_name_id,
        wardrobeslotid         = EXCLUDED.wardrobeslotid,
        stat_enchant_name0     = EXCLUDED.stat_enchant_name0,
        stat_enchant_name1     = EXCLUDED.stat_enchant_name1,
        stat_enchant_name2     = EXCLUDED.stat_enchant_name2,
        stat_enchant_name3     = EXCLUDED.stat_enchant_name3,
        stat_enchant_name4     = EXCLUDED.stat_enchant_name4,
        stat_enchant_name5     = EXCLUDED.stat_enchant_name5,
        proc_tool_nameid       = EXCLUDED.proc_tool_nameid,
        obtain_skin_type       = EXCLUDED.obtain_skin_type,
        expire_skin_time       = EXCLUDED.expire_skin_time,
        limit_enchant_count    = EXCLUDED.limit_enchant_count,
        authorize_count        = EXCLUDED.authorize_count,
        vanish_point           = EXCLUDED.vanish_point,
        enchant_prob_addition  = EXCLUDED.enchant_prob_addition,
        option_prob_addition   = EXCLUDED.option_prob_addition,
        keynameid              = EXCLUDED.keynameid,
        exceedstate            = EXCLUDED.exceedstate,
        exceedskillid1         = EXCLUDED.exceedskillid1,
        exceedskillid2         = EXCLUDED.exceedskillid2,
        exceedskillid3         = EXCLUDED.exceedskillid3,
        baseskillid            = EXCLUDED.baseskillid,
        enhanceskillgroup      = EXCLUDED.enhanceskillgroup,
        enhanceskilllevel      = EXCLUDED.enhanceskilllevel,
        equipleveldown         = EXCLUDED.equipleveldown,
        randomattr1  = EXCLUDED.randomattr1,  randomvalue1  = EXCLUDED.randomvalue1,
        randomattr2  = EXCLUDED.randomattr2,  randomvalue2  = EXCLUDED.randomvalue2,
        randomattr3  = EXCLUDED.randomattr3,  randomvalue3  = EXCLUDED.randomvalue3,
        randomattr4  = EXCLUDED.randomattr4,  randomvalue4  = EXCLUDED.randomvalue4,
        randomattr5  = EXCLUDED.randomattr5,  randomvalue5  = EXCLUDED.randomvalue5,
        randomattr6  = EXCLUDED.randomattr6,  randomvalue6  = EXCLUDED.randomvalue6,
        randomattr7  = EXCLUDED.randomattr7,  randomvalue7  = EXCLUDED.randomvalue7,
        randomattr8  = EXCLUDED.randomattr8,  randomvalue8  = EXCLUDED.randomvalue8,
        randomattr9  = EXCLUDED.randomattr9,  randomvalue9  = EXCLUDED.randomvalue9,
        randomattr10 = EXCLUDED.randomattr10, randomvalue10 = EXCLUDED.randomvalue10,
        skill_skin_name_id     = EXCLUDED.skill_skin_name_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemenchant_20180615(
    BIGINT, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER
);
-- +goose StatementEnd
