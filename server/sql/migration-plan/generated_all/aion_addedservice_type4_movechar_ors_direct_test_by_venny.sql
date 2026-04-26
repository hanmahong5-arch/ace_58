-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_ORS_DIRECT_TEST_by_venny.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_ors_direct_test_by_venny(_server_id INTEGER, _db_user_id TEXT, _db_passwd TEXT, _service_db_idx INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: RAISERROR



-- serviceType 4 : 캐릭터 서버 이전 처리



declare _check_connect_server_id	int

declare _ret	int

declare _err_str	nvarchar(256)

declare _check_error	int

declare _server	int



/*

_server := 0

select top (1) _server = server_id from server_info

where info_name = 'SERVER_START_TIME'

order by int_value desc





if _server = 0 or (_server_id <> 0 and _server <> _server_id)

begin

	RAISERROR('Check ServerId Error!!!', 1, 1)

	return

end

*/



_server := _server_id



_check_error := 0



SELECT fromServer INTO _check_connect_server_id from AionAddedService (nolock)

where serviceType = 4 and serviceFlag = 0 and status = 0 and idx = _service_db_idx



exec aion_AddedService_Type4_MoveChar_CheckConn_ORS _check_connect_server_id, _db_user_id, _db_passwd, _ret output, _err_str output

if _ret != 0

begin

	_check_error := 1
RAISE NOTICE '%', _err_str;

end



if _check_error <> 0

begin

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



-- 우선은 status 는 고려하지 말자...

SELECT idx, _from_server = fromServer, _from_char_id = fromCharacterId, _from_char_name = fromCharacter, _char_id = toCharacterId, _char_name = toCharacter, _from_uid = fromUid, _from_race = fromRace INTO _idx from AionAddedService (nolock)

where serviceType = 4 and serviceFlag = 0 and status = 0 and idx = _service_db_idx





_char_id := _char_id

_status := -1



exec aion_AddedService_Type4_MoveChar_CheckLocalChar_ORS _from_uid, _from_race, _val output

if _val != 0	GOTO UpdateRetVal



exec aion_AddedService_Type4_MoveChar_CheckOrgChar_ORS _from_server, _server, _db_user_id, _db_passwd, _from_char_id, _from_char_name, _val output

if _val != 0	GOTO UpdateRetVal



exec aion_AddedService_Type4_MoveChar_Process_ORS _db_user_id, _db_passwd, _from_server, _from_char_id, _from_char_name, _server, _char_id, _char_name, _char_id output, _val output

if _val != 0	GOTO UpdateRetVal



_status := 1	-- 성공



UpdateRetVal:

	update AionAddedService Set status = _status, serviceFlag = _val, toCharacterId = _char_id, applyDate = NOW() where idx = _idx;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_ors_direct_test_by_venny;
-- +goose StatementEnd
