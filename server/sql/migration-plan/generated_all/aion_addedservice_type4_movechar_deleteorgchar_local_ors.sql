-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_DeleteOrgChar_local_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_deleteorgchar_local_ors(_server_id INTEGER, _from_server_id INTEGER, _char_id INTEGER, _char_name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _ret int

_ret := 0



if _char_id <> 0

begin

	-- 캐릭터 이름을 다른 사람이 다시 사용하지 못 하도록 forbidden_char에 추가

	insert into forbidden_char (

				FORBIDDEN_TYPE, FORBIDDEN_REASON, WORLD_ID,

				FORBIDDEN_CHAR, FORBIDDEN_ACCOUNT_NM,

				STATUS, LOGIN_ID, LOGIN_NM, REGDATE)

	values(1, 3, _from_server_id, _char_name, '', 0, 'AddedService', 'Type4_MoveServer', NOW())



	if @_error <> 0	or @_rowcount = 0

	begin 

		_ret := -11029	-- Forbidden_char Insert Error!!!

		GOTO send_result

	end



	-- 캐릭터 삭제 처리

	declare _delete_date int

	_delete_date := GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'), 0);



	update user_data 

		set delete_date = _delete_date, 

			delete_complete_date = _delete_date, 

			delete_type	= _server_id	-- 캐릭터 이전으로 인한 삭제 이전한 곳의 ServerId를 넣어 준다.

		where char_id = _char_id



	if @_error <> 0	or @_rowcount = 0

	begin

		_ret := -11030

		goto send_result

	end



	-- Item Table에서 Vendor에 있는 항목들을 모두 인벤토리로 옮김

	-- 옮겨간 캐릭터가 올려 놓은 목록이 없도록.

	update user_item 

		set warehouse = 0 

		where char_id = _char_id and warehouse = 4



	-- Vendor Table에서 삭제

	DELETE FROM vendor_item_light where char_id = _char_id



	DELETE FROM vendor_item_dark where char_id = _char_id



end



send_result:

select _ret as result;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_deleteorgchar_local_ors;
-- +goose StatementEnd
