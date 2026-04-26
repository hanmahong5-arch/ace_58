-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_Mobile_GetBingoRewardInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mobile_getbingorewardinfo(_board_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	SELECT char_id

	FROM user_bingo_reward

	WHERE board_id = _board_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mobile_getbingorewardinfo;
-- +goose StatementEnd
