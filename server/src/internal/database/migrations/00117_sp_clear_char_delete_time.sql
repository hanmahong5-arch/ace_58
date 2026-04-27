-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_ClearCharDeleteTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClearCharDeleteTime.sql
--
-- Cancels a pending soft-delete by zeroing user_data.delete_date. Invoked
-- by CM_RESTORE_CHARACTER (player clicks "cancel deletion" before the
-- 7-day sweeper fires) and by the GM tool's "undelete" action.
--
-- T-SQL body:
--   UPDATE user_data
--   SET delete_date = 0,
--       change_info_time = dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)
--   WHERE char_id = @nCharId

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearchardeletetime(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearchardeletetime(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET delete_date      = 0,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearchardeletetime(INTEGER);
-- +goose StatementEnd
