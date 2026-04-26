-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetMoveCharList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmovecharlist(_server INTEGER, _db_user_id TEXT, _db_passwd TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	select idx, fromServer, fromUid, fromCharacterId, fromCharacter, fromAccount

	from AionAddedService (nolock)

	where serviceType = 4 and serviceFlag = 0 and status = 0 and toServer = _server 


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmovecharlist;
-- +goose StatementEnd
