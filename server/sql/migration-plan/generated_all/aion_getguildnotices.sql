-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildNotices.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildnotices(_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT  noticetime1, notice1,

				noticetime2, notice2,

				noticetime3, notice3,

				noticetime4, notice4,

				noticetime5, notice5,

				noticetime6, notice6,

				noticetime7, notice7					

FROM guild

where id=_guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildnotices;
-- +goose StatementEnd
