-- AionCore 5.8 — Sprint 1.1a port #4: aion_SetCharDeleteTime.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetCharDeleteTime.sql
-- Original T-SQL: UPDATE user_data SET delete_date=@nDeleteTime,
--                 change_info_time=dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)
--                 WHERE char_id=@nCharId
-- Auto-port pass: GetUTCDate() → (NOW() AT TIME ZONE 'UTC') and dbo. strip
-- both correct out of the box. Helper UDF deployed in 00002_pve_scaffold.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchardeletetime(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setchardeletetime(
    _char_id     INTEGER,
    _delete_time INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_data
       SET delete_date      = _delete_time,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setchardeletetime(INTEGER, INTEGER);
-- +goose StatementEnd
