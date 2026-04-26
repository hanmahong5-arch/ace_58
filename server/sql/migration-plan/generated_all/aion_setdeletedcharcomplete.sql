-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetDeletedCharComplete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setdeletedcharcomplete(_char_id INTEGER, _delete_complete_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	UPDATE user_data 

	SET delete_complete_date = _delete_complete_time ,guild_id = 0,

		change_info_time = GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)

	WHERE char_id = _char_id and delete_complete_date = 0 and delete_date != 0 and delete_date <= _delete_complete_time



	-- dual charge 처리

	declare _acc_id as int

	declare _user_id as varchar(40)

	declare _level as smallint

	declare _max_char_id as int

	declare _max_level as smallint

	

	if @_rowcount = 1

	Begin

		SELECT account_id, _user_id=user_id, _level=lev INTO _acc_id From user_data with(nolock) Where char_id=_char_id;

		Select top(1) _max_char_id=char_id, _max_level=lev From user_data with(nolock) Where account_id=_acc_id and delete_complete_date=0 Order by lev desc

		select _user_id, _acc_id, _level,COALESCE(_max_char_id, 0), COALESCE(_max_level, 0)

	End


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setdeletedcharcomplete;
-- +goose StatementEnd
