-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetUserBMPackList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserbmpacklist(_char_id INTEGER, _pack_state INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT pack_type, expiration_time

	FROM user_bm_pack

	WHERE char_id = _char_id AND pack_state = _pack_state


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserbmpacklist;
-- +goose StatementEnd
