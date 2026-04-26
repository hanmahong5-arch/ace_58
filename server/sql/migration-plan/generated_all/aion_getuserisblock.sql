-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetUserIsBlock.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserisblock(_char_id INTEGER, _targetname TEXT, _target_id INTEGER, _isblock INTEGER, _optionflag INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	_target_id := 0

	SELECT COALESCE(char_id,0) INTO _target_id from user_data with (nolock) where user_id = _targetname and delete_complete_date=0 and race = (select race from user_data with(nolock) where char_id = _char_id)

	_isblock := 0

	_optionflag := 0

	

	if _target_id is not null and _target_id != 0	

	begin

		-- Insert statements for procedure here

		if exists (SELECT block_id from user_block with(nolock) where char_id = _target_id and block_id = _char_id)

			_isblock := 1

		else

			_isblock := 0

		select _optionflag = COALESCE(optionflags,0) from user_data (nolock) where char_id = _target_id

	end		

	return

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserisblock;
-- +goose StatementEnd
