-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AnswerOfflineBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_answerofflinebuddy(_char_id INTEGER, _charname TEXT, _inviter_id INTEGER, _invitername TEXT, _level INTEGER, _class INTEGER, _gender INTEGER, _worldnum INTEGER, _todayword TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


		

	declare _result int

	

	_level := 0

	_class := 0

	_gender := 0

	_worldnum := 0

	_todayword := N''

	

	if EXISTS(SELECT char_id FROM user_buddy1 WHERE char_id = _char_id and buddy_id = _inviter_id)

		return 2	--already		

	

	if not exists (select char_id from user_data(nolock) where char_id = _inviter_id and race = (select race from user_data(nolock) where char_id = _char_id))

		return 3   -- not exist (and race check)

	

	declare _buddy_count int

	declare _count int

	

	SELECT COUNT(*) INTO _buddy_count from user_buddy1 where char_id = _char_id 	

	

	if (_buddy_count >= 200) 

		return 5; --out of buddy

	

	SELECT COUNT(*) INTO _buddy_count from user_buddy1 where char_id = _inviter_id	

	

	if (_buddy_count >= 200) 

		return 5;	

	

	INSERT user_buddy1 (char_id, buddy_id, delete_flag) VALUES (_inviter_id, _char_id, 0)	--초대 대상이 오프라인이므로, 이때 추가해주기.

	

	SELECT lev, _class = class, _gender = gender, _worldnum = world, _todayword = daily_comment INTO _level from user_data (nolock) where char_id = _inviter_id 

	return 0;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_answerofflinebuddy;
-- +goose StatementEnd
