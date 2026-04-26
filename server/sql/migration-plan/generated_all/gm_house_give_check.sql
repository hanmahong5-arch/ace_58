-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_house_give_check.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_house_give_check(_owner_id INTEGER, _owner_name TEXT, _level INTEGER, _quest INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	declare _ret int

    -- Insert statements for procedure here

	if exists (select char_id from user_finished_quest (Nolock) where char_id = _owner_id and quest_id in (18802, 28802))	

		_quest := 1	

	else

		_quest := 0

	

	SELECT user_id, _level = lev INTO _owner_name from user_data (Nolock) where char_id = _owner_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_house_give_check;
-- +goose StatementEnd
