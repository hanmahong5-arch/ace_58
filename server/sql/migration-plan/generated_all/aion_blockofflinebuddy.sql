-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_BlockOfflineBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_blockofflinebuddy(_char_id INTEGER, _inviter_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


		

	declare _result int

	

	if exists (select buddy_id from user_buddy1 where char_id = _char_id and  buddy_id = _inviter_id and delete_flag = 0)

		return 4;	-- BKT_INVALID

	if exists (select block_id from user_block where char_id = _char_id and block_id = _inviter_id)

		return 0;	--이미 있지만 에러가 없다.

	

	declare _blockcount int

	

	SELECT COUNT(*) INTO _blockcount from user_block where char_id = _char_id

	

	

	if (_blockcount >= 200) 

		return 3;

	

	insert into user_block (char_id, block_id, comment) values (_char_id, _inviter_id, '')

	

	return 0;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_blockofflinebuddy;
-- +goose StatementEnd
