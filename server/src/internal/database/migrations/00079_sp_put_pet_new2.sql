-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_PutPetNew2.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutPetNew2.sql
--
-- Inserts a new user_pet row and returns the BIGSERIAL id (mirrors @@IDENTITY).
-- change_info_time is computed via GetUnixtimeWithUTCAdjust(NOW(), 0) — same
-- helper used in aion_PutChar (epoch seconds at UTC).
-- Returns 0 on failure (caller treats 0 as "could not adopt").

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpetnew2(TEXT, BYTEA, INTEGER, INTEGER, SMALLINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putpetnew2(
    _name                  TEXT,
    _visual_data           BYTEA,
    _char_id               INTEGER,
    _name_id               INTEGER,
    _slot_id               SMALLINT,
    _function_data1        BIGINT,
    _function_data1_ex1    BIGINT,
    _function_data1_ex2    BIGINT,
    _function_data1_ex3    BIGINT,
    _function_data2        BIGINT,
    _function_data2_ex1    BIGINT,
    _function_data2_ex2    BIGINT,
    _function_data2_ex3    BIGINT,
    _visual_data_size      INTEGER,
    _expired_time          INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    new_id BIGINT;
    cit    BIGINT;
BEGIN
    cit := GetUnixtimeWithUTCAdjust(NOW(), 0);
    INSERT INTO user_pet
           (char_id, name_id, slot_id, name,
            function_data1, function_data1_ex1, function_data1_ex2, function_data1_ex3,
            function_data2, function_data2_ex1, function_data2_ex2, function_data2_ex3,
            visual_data_size, visual_data, change_info_time, expired_time)
    VALUES (_char_id, _name_id, _slot_id, _name,
            _function_data1, _function_data1_ex1, _function_data1_ex2, _function_data1_ex3,
            _function_data2, _function_data2_ex1, _function_data2_ex2, _function_data2_ex3,
            _visual_data_size, _visual_data, cit, _expired_time)
    RETURNING id INTO new_id;
    RETURN new_id;
EXCEPTION WHEN others THEN
    RETURN 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpetnew2(TEXT, BYTEA, INTEGER, INTEGER, SMALLINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, BIGINT, INTEGER, INTEGER);
-- +goose StatementEnd
