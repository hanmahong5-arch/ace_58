-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetInstanceExtraCountAbyssOP.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetInstanceExtraCountAbyssOP.sql
--
-- Two distinct behaviours encoded in @mapNumber:
--   _map_number = 0 → "wipe all rows for this char": set every row's
--                     next_reset_time = 0 (does NOT delete; matches T-SQL).
--   _map_number > 0 → upsert the (char, map) row.
-- Verbatim preserved: the wipe path zeroes next_reset_time but does NOT
-- touch extra_count_abyssop, so the next read with @opResetTime > 0 will
-- skip the row even though the count is still non-zero (NCSoft's intended
-- "soft reset" mechanic).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstanceextracountabyssop(INTEGER, INTEGER, SMALLINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinstanceextracountabyssop(
    _char_id          INTEGER,
    _map_number       INTEGER,
    _extra_count      SMALLINT,
    _next_reset_time  BIGINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF _map_number = 0 THEN
        UPDATE user_instance_extracount
           SET next_reset_time = 0
         WHERE char_id = _char_id;
    ELSE
        INSERT INTO user_instance_extracount (char_id, map_number, extra_count_abyssop, next_reset_time)
        VALUES (_char_id, _map_number, _extra_count, _next_reset_time)
        ON CONFLICT (char_id, map_number) DO UPDATE
           SET extra_count_abyssop = EXCLUDED.extra_count_abyssop,
               next_reset_time     = EXCLUDED.next_reset_time;
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinstanceextracountabyssop(INTEGER, INTEGER, SMALLINT, BIGINT);
-- +goose StatementEnd
