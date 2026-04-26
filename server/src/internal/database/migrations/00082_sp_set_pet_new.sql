-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_SetPetNew.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetPetNew.sql
--
-- Updates pet attribute blocks + slot + expire-time, matching by name_id and
-- char_id (verbatim with NCSoft — the @nId parameter is treated as name_id
-- here, NOT as the pet row id).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetnew(BIGINT, INTEGER, SMALLINT, INTEGER, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetnew(
    _name_id               BIGINT,
    _char_id               INTEGER,
    _slot_id               SMALLINT,
    _expire_time           INTEGER,
    _function_data1        BIGINT,
    _function_data1_ex1    BIGINT,
    _function_data1_ex2    BIGINT,
    _function_data1_ex3    BIGINT,
    _function_data2        BIGINT,
    _function_data2_ex1    BIGINT,
    _function_data2_ex2    BIGINT,
    _function_data2_ex3    BIGINT
)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
    cit BIGINT;
BEGIN
    cit := GetUnixtimeWithUTCAdjust(NOW(), 0);
    UPDATE user_pet
       SET slot_id            = _slot_id,
           expired_time       = _expire_time,
           function_data1     = _function_data1,
           function_data1_ex1 = _function_data1_ex1,
           function_data1_ex2 = _function_data1_ex2,
           function_data1_ex3 = _function_data1_ex3,
           function_data2     = _function_data2,
           function_data2_ex1 = _function_data2_ex1,
           function_data2_ex2 = _function_data2_ex2,
           function_data2_ex3 = _function_data2_ex3,
           change_info_time   = cit
     WHERE name_id = _name_id::INTEGER AND char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetnew(BIGINT, INTEGER, SMALLINT, INTEGER, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT);
-- +goose StatementEnd
