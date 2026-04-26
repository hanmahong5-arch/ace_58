-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_OnLine_Request_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_online_request_ors(_from_uid INTEGER, _from_account TEXT, _from_char TEXT, _from_char_id INTEGER, _from_server_id INTEGER, _server_id INTEGER, _ret INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	insert AionAddedService(postDate, serviceType, fromUid, fromAccount, fromServer, toServer, fromCharacter, fromCharacterId, status, serviceFlag)

	values (NOW(), 4, _from_uid, _from_account, _from_server_id, _server_id, _from_char, _from_char_id, 0, 0)



	_ret := SCOPE_IDENTITY()

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_online_request_ors;
-- +goose StatementEnd
