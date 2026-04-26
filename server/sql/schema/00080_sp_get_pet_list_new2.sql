-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetPetListNew2.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetPetListNew2.sql
--
-- Returns all pets a character owns, with create_date converted to a unix
-- epoch using the local-clock UTC adjustment helper (mirrors NCSoft's
-- GetUtcAdjustSecWithUTC_Local + GetUnixtimeWithUTCAdjust pipeline).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetlistnew2(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpetlistnew2(
    _char_id INTEGER
)
RETURNS TABLE (
    out_id                    BIGINT,
    out_name_id               INTEGER,
    out_slot_id               SMALLINT,
    out_name                  TEXT,
    out_function_data1        BIGINT,
    out_function_data1_ex1    BIGINT,
    out_function_data1_ex2    BIGINT,
    out_function_data1_ex3    BIGINT,
    out_function_data2        BIGINT,
    out_function_data2_ex1    BIGINT,
    out_function_data2_ex2    BIGINT,
    out_function_data2_ex3    BIGINT,
    out_create_date_unix      BIGINT,
    out_visual_data_size      INTEGER,
    out_visual_data           BYTEA,
    out_expired_time          INTEGER
)
LANGUAGE plpgsql AS $$
DECLARE
    utc_adjust BIGINT;
BEGIN
    utc_adjust := GetUtcAdjustSecWithUTC_Local(NOW() AT TIME ZONE 'UTC', NOW());
    RETURN QUERY
    SELECT id, name_id, slot_id, name,
           function_data1, function_data1_ex1, function_data1_ex2, function_data1_ex3,
           function_data2, function_data2_ex1, function_data2_ex2, function_data2_ex3,
           GetUnixtimeWithUTCAdjust(create_date, (utc_adjust / 3600)::INTEGER),
           visual_data_size, visual_data, expired_time
      FROM user_pet
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetlistnew2(INTEGER);
-- +goose StatementEnd
