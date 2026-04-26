-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_deleteOfflineBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteofflinebuddy(_char_id INTEGER, _inviter_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


		

	delete from user_buddy_offline where USER_ID = _char_id and inviter_id = _inviter_id

	delete from user_buddy_offline where USER_ID = _inviter_id and inviter_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteofflinebuddy;
-- +goose StatementEnd
