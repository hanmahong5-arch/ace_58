-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_GuildDA_SrchGuildEmblemByID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_guildda_srchguildemblembyid(_guild_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select emblem,emblem_img,emblem_img_version,emblem_img_last_version,emblem_bgcolor

			from guild

			where id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_guildda_srchguildemblembyid;
-- +goose StatementEnd
