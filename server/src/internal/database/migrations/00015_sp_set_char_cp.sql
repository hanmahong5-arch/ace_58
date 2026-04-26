-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetCharCP.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharCP.sql
-- Sets champion-point currency on PvE rewards.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharcp(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharcp(_char_id INTEGER, _cp INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET cp = _cp,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharcp(INTEGER, INTEGER);
-- +goose StatementEnd
