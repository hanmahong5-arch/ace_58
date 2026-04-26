-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_GuildDA_SrchGuildHistory.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_guildda_srchguildhistory(_guild_id TEXT, _view_count INTEGER, _top_count INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	



			select	top(_view_count) id, guild_id, eventdate, eventtype, eventparam, eventparam2

			from	guild_history(nolock)

			where	guild_id=_guild_id and id not in (select top(_top_count) id from guild_history(nolock) where guild_id=_guild_id order by id desc) 

			order by id desc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_guildda_srchguildhistory;
-- +goose StatementEnd
