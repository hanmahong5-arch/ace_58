-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AvatarAddedService_Type4_MoveChar_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_avataraddedservice_type4_movechar_ors(_server_id INTEGER, _db_user_id TEXT, _db_passwd TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: RAISERROR
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: CLOSE
-- TODO: unsupported T-SQL construct: DEALLOCATE



-- serviceType 4:某腐磐 辑滚捞傈, 14:橇府固决 某腐磐 辑滚捞傈, 16:付胶磐辑滚 某腐磐 辑滚捞傈



declare _check_connect_server_id	int

declare _ret	int

declare _err_str	nvarchar(256)

declare _check_error	int

declare _server	int



_server := 0

select top (1) _server = server_id from server_info

where info_name = 'SERVER_START_TIME'

order by int_value desc





if _server = 0 or (_server_id <> 0 and _server <> _server_id)

begin

	RAISERROR('Check ServerId Error!!!', 1, 1)

	return

end



_check_error := 0



declare checkConn_cursor	cursor for

select fromServer from AvatarAionAddedService (nolock)

where (serviceType = 4 or serviceType = 14 or serviceType = 16) and serviceFlag = 0 and status = 0 and toServer = _server

group by fromServer



open checkConn_cursor

fetch next from checkConn_cursor into _check_connect_server_id



while @_fetch_status = 0

begin

	exec aion_AddedService_Type4_MoveChar_CheckConn_ORS _check_connect_server_id, _db_user_id, _db_passwd, _ret output, _err_str output

	if _ret != 0

	begin

		_check_error := 1
RAISE NOTICE '%', _err_str;

	end



	fetch next from checkConn_cursor into _check_connect_server_id

end



close checkConn_cursor

deallocate checkConn_cursor



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



declare _service_type int

declare _preminum int

declare _with_account_warehouse int

declare _mileage int



-- 快急篮 status 绰 绊妨窍瘤 富磊...

declare moveChar_cursor cursor for

select idx, fromServer, fromCharacterId, fromCharacter, toCharacterId, toCharacter, fromUid, fromRace, serviceType, warehouse, mileage from AvatarAionAddedService (nolock)

where (serviceType = 4  or serviceType = 14 or serviceType = 16) and serviceFlag = 0 and status = 0 and toServer = _server



open moveChar_cursor

fetch next from moveChar_cursor	into _idx, _from_server, _from_char_id, _from_char_name, _char_id, _char_name, _from_uid, _from_race, _service_type, _with_account_warehouse, _mileage



while @_fetch_status = 0

begin

	_char_id := _char_id

	_status := -1

	

	if _service_type = 14  

	begin

		_preminum := 1

	end

	else begin

		_preminum := 0

	end



	exec aion_AddedService_Type4_MoveChar_CheckLocalChar_ORS _from_uid, _from_race, _val output

	if _val != 0	GOTO UpdateRetVal



	exec aion_AvatarAddedService_Type4_MoveChar_CheckOrgChar_ORS _from_server, _server, _db_user_id, _db_passwd, _from_char_id, _from_char_name, _preminum, _with_account_warehouse, 0, _val output

	if _val != 0	GOTO UpdateRetVal



	exec aion_AvatarAddedService_Type4_MoveChar_Process_ORS _db_user_id, _db_passwd, _from_server, _from_char_id, _from_char_name, _server, _char_id, _char_name, _preminum, _with_account_warehouse, _mileage, _char_id output, _val output

	if _val != 0	GOTO UpdateRetVal



	_status := 1	-- 己傍



UpdateRetVal:

	update AvatarAionAddedService Set status = _status, serviceFlag = _val, toCharacterId = _char_id, applyDate = NOW() where idx = _idx



	fetch next from moveChar_cursor	into _idx, _from_server, _from_char_id, _from_char_name, _char_id, _char_name, _from_uid, _from_race, _service_type, _with_account_warehouse, _mileage

end



close moveChar_cursor

deallocate moveChar_cursor;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_avataraddedservice_type4_movechar_ors;
-- +goose StatementEnd
