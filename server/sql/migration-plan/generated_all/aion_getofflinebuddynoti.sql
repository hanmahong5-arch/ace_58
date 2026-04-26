-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetOfflineBuddyNoti.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getofflinebuddynoti(_charid INTEGER, _request_count INTEGER, _lastmsg TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	--로그인 해올 때 그 사용자와 관련된 offline 버디 요청들을 기간을 확인해서 정리한다.

	--delete from user_buddy_offline where (USER_ID = _charid or inviter_id = _charid) and DATEDIFF(day, createdate, NOW())> 7

    -- Insert statements for procedure here

    declare _name varchar(50)

    declare _msg varchar(255)

    SELECT COUNT(*) INTO _request_count from user_buddy_offline with(nolock) where USER_ID = _charid

	SELECT _name = inviter_name, _msg = inviter_msg from user_buddy_offline with(nolock) where USER_ID = _charid and DATEDIFF(day, createdate, NOW())<= 7 order by id desc

	if _name is not null

		_lastmsg := _name + ':' + _msg

	else 

		_lastmsg := '' /* LIMIT 1 appended */ LIMIT 1;

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getofflinebuddynoti;
-- +goose StatementEnd
