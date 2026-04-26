-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_OnLine_Execute_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_online_execute_ors(_service_id INTEGER, _db_user_id TEXT, _db_passwd TEXT, _ret INTEGER, _err_str TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: RAISERROR





--declare _ret	int

--declare _err_str	nvarchar(256)



declare _check_connect_server_id	int

declare _check_error	int

declare _server	int

declare	_server_id	int



_ret := 0

_check_error := 0

_err_str := 'Process'



SELECT fromServer, _server = toServer INTO _check_connect_server_id  from AionAddedService (nolock)

where serviceType = 4 and serviceFlag = 0 and status = 0 and idx = _service_id



exec aion_AddedService_Type4_MoveChar_CheckConn_ORS _check_connect_server_id, _db_user_id, _db_passwd, _ret output, _err_str output

if _ret != 0

begin

	_check_error := 1
RAISE NOTICE '%', _err_str;

end



if _check_error <> 0

begin

	_ret := -100

	RAISERROR('CheckConn Error!!!', 1, 1)

	return

end



declare	_idx	int

declare	_from_server	int

declare _from_char_id	int

declare _from_char_name	nvarchar(20)

declare _char_id	int

declare _char_name	nvarchar(20)

declare _from_uid	int

declare _from_race	int



declare _linked_server_name nvarchar(50)

declare _val	int

declare _status int

declare _char_id int



declare _service_type int

declare _preminum int

declare _with_account_warehouse int



-- 우선은 status 는 고려하지 말자...

SELECT idx, _from_server = fromServer, _from_char_id = fromCharacterId, _from_char_name = fromCharacter, _char_id = toCharacterId, _char_name = toCharacter, _from_uid = fromUid, _from_race = fromRace, _service_type=serviceType, _with_account_warehouse=warehouse INTO _idx  from AionAddedService (nolock)

where (serviceType = 4 or serviceType = 14) and serviceFlag = 0 and status = 0 and idx = _service_id





_char_id := _char_id

_status := -1

_err_str := 'No success'



if _service_type = 8  

begin

	_preminum := 1

end

else begin

	_preminum := 0

end



--print 'start check other server'



exec aion_AddedService_Type4_MoveChar_CheckLocalChar_ORS _from_uid, _from_race, _val output

if _val != 0	GOTO UpdateRetVal



exec aion_AddedService_Type4_MoveChar_CheckOrgChar_ORS _from_server, _server, _db_user_id, _db_passwd, _from_char_id, _from_char_name, _preminum, _with_account_warehouse, 1, _val output

if _val != 0	GOTO UpdateRetVal



exec aion_AddedService_Type4_MoveChar_Process_ORS _db_user_id, _db_passwd, _from_server, _from_char_id, _from_char_name, _server, _char_id, _char_name, _preminum, _with_account_warehouse, _char_id output, _val output

if _val != 0	GOTO UpdateRetVal



_status := 1	-- 성공

_err_str := 'success'



UpdateRetVal:

	update AionAddedService Set status = _status, serviceFlag = _val, toCharacterId = _char_id, applyDate = NOW() where idx = _idx

	_ret := _val;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_online_execute_ors;
-- +goose StatementEnd
