-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetPetitionMsg.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpetitionmsg(_char_id INTEGER, _local_sv INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




SELECT _local_sv AS petition_sv_id, petition_msg FROM user_data WHERE char_id = _char_id

UNION ALL

SELECT petition_sv_id, msg FROM user_petition_msg WHERE char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetitionmsg;
-- +goose StatementEnd
