-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_resetwebnotify_20110715.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_resetwebnotify_20110715(_charid INTEGER, _category INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	if EXISTS (select id from user_webnotify with (updlock) where char_id = _charid and category = _category)				

		update user_webnotify set unsent = 0 where char_id = _charid and category = _category

	else

		insert into user_webnotify (char_id, category, unsent, msg) values (_charid, _category, 0, '')

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_resetwebnotify_20110715;
-- +goose StatementEnd
