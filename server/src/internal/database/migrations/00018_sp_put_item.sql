-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_PutItem_20150921.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutItem_20150921.sql
-- Inserts a row into user_item; if any "non-default" field is non-zero (skin,
-- enchant, soul_bound, etc.) also inserts a sister row into user_item_option.
--
-- T-SQL had @dbId as OUTPUT param + return; we return BIGINT (the new row id)
-- which is more idiomatic for plpgsql callers.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putitem_20150921(
    INTEGER, INTEGER, INTEGER, BIGINT, BIGINT, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TEXT,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putitem_20150921(
    _char_id              INTEGER,
    _name_id              INTEGER,
    _slot_id              INTEGER,
    _amount               BIGINT,
    _tid                  BIGINT,
    _slot_num             INTEGER,
    _warehouse            INTEGER,
    _soul_bound           INTEGER,
    _enchant_count        INTEGER,
    _skin_name_id         INTEGER,
    _stat_enchant_name0   INTEGER,
    _stat_enchant_name1   INTEGER,
    _stat_enchant_name2   INTEGER,
    _stat_enchant_name3   INTEGER,
    _stat_enchant_name4   INTEGER,
    _stat_enchant_name5   INTEGER,
    _option_count         INTEGER,
    _dye_info             INTEGER,
    _proc_tool_nameid     INTEGER,
    _expired_time         INTEGER,
    _producer             TEXT,
    _buy_amount           INTEGER,
    _buy_duration         INTEGER,
    _obtain_skin_type     INTEGER,
    _expire_skin_time     INTEGER,
    _dynamic_property     INTEGER,
    _server_of_origin     INTEGER,
    _expire_dye_time      INTEGER,
    _random_option        INTEGER,
    _limit_enchant_count  INTEGER,
    _reidentify_count     INTEGER,
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
    _enhance_skill_level  INTEGER
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _new_id BIGINT;
BEGIN
    INSERT INTO user_item (
        char_id, name_id, slot_id, amount, tid, slot, warehouse,
        producer, expired_time, buy_amount, buy_duration,
        dynamic_property, server_of_origin
    ) VALUES (
        _char_id, _name_id, _slot_id, _amount, _tid, _slot_num, _warehouse,
        _producer, _expired_time, _buy_amount, _buy_duration,
        _dynamic_property, _server_of_origin
    )
    RETURNING id INTO _new_id;

    -- Mirror the T-SQL "any non-default → also insert option row" gate
    IF _random_option > 0 OR _skin_name_id > 0
       OR _stat_enchant_name0 > 0 OR _stat_enchant_name1 > 0
       OR _stat_enchant_name2 > 0 OR _stat_enchant_name3 > 0
       OR _stat_enchant_name4 > 0 OR _stat_enchant_name5 > 0
       OR _proc_tool_nameid > 0 OR _enchant_count > 0
       OR _soul_bound > 0 OR _option_count > 0 OR _dye_info <> 0
       OR _limit_enchant_count > 0 OR _authorize_count > 0
       OR _vanish_point > 0 OR _enchant_prob_addition > 0
       OR _option_prob_addition > 0 OR _key_name_id > 0
    THEN
        INSERT INTO user_item_option (
            id, char_id, soul_bound, enchant_count, skin_name_id,
            stat_enchant_name0, stat_enchant_name1, stat_enchant_name2,
            stat_enchant_name3, stat_enchant_name4, stat_enchant_name5,
            option_count, dye_info, proc_tool_nameid,
            obtain_skin_type, expire_skin_time, expire_dye_time,
            random_option, limit_enchant_count, reidentify_count,
            authorize_count, vanish_point,
            enchant_prob_addition, option_prob_addition,
            KeyNameId, exceedState, ExceedSkillId1, ExceedSkillId2,
            ExceedSkillId3, BaseSkillId, enhanceSkillGroup, enhanceSkillLevel
        ) VALUES (
            _new_id, _char_id, _soul_bound, _enchant_count, _skin_name_id,
            _stat_enchant_name0, _stat_enchant_name1, _stat_enchant_name2,
            _stat_enchant_name3, _stat_enchant_name4, _stat_enchant_name5,
            _option_count, _dye_info, _proc_tool_nameid,
            _obtain_skin_type, _expire_skin_time, _expire_dye_time,
            _random_option, _limit_enchant_count, _reidentify_count,
            _authorize_count, _vanish_point,
            _enchant_prob_addition, _option_prob_addition,
            _key_name_id, _exceed_state, _exceed_skill_id1, _exceed_skill_id2,
            _exceed_skill_id3, _base_skill_id, _enhance_skill_group, _enhance_skill_level
        );
    END IF;

    RETURN _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putitem_20150921(
    INTEGER, INTEGER, INTEGER, BIGINT, BIGINT, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TEXT,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
);
-- +goose StatementEnd
