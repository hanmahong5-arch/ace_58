-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddOfflineBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addofflinebuddy(_char_id INTEGER, _inviter_id INTEGER, _inviter_name TEXT, _message TEXT, _level INTEGER, _class INTEGER, _gender INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	if exists (select inviter_id from user_buddy_offline with(nolock) where user_id = _char_id and inviter_id = _inviter_id)

		return 12;

	

	if exists (select inviter_id from user_buddy_offline with(nolock) where user_id = _inviter_id and inviter_id = _char_id)	

		return 19;

		

	declare _buddy_count int

	declare _count int

	declare _inter_count int

	

	SELECT COUNT(*) INTO _buddy_count from user_buddy1 where char_id = _char_id 

	select _count = COUNT(*) from user_buddy_offline where user_id = _char_id

	select _inter_count = COUNT(*) from user_buddy_inter where char_id = _char_id

	

	if (_buddy_count + _count + _inter_count>= 100) 

		return 14;

	

	SELECT COUNT(*) INTO _buddy_count from user_buddy1 where char_id = _inviter_id

	select _count = COUNT(*) from user_buddy_offline where inviter_id = _inviter_id

	select _inter_count = COUNT(*) from user_buddy_inter where char_id = _inviter_id

	

	if (_buddy_count + _count+_inter_count >= 100) 

		return 13;

	

	insert into user_buddy_offline (user_id, inviter_id, inviter_name, inviter_msg, userlevel, userclass, gender) values (_char_id, _inviter_id, _inviter_name, _message, _level, _class, _gender)

	

	return 11;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addofflinebuddy;
-- +goose StatementEnd
