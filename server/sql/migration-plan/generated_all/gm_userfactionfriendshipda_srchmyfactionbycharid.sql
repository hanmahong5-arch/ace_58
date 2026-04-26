-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFactionFriendShipDA_SrchMyFactionByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfactionfriendshipda_srchmyfactionbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			select	char_id, faction_id, friendship, jointime, factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime, factionquest_lastfinishedtime, factionquest_finishedcount

			from	user_faction_friendship(nolock) 

			where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfactionfriendshipda_srchmyfactionbycharid;
-- +goose StatementEnd
