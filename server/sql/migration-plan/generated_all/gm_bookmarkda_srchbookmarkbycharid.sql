-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_BookmarkDA_SrchBookmarkByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_bookmarkda_srchbookmarkbycharid(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

						

			select bookmark_id, char_id, bookmark, world, x, y, z

			from bookmark(nolock)

			where char_id = _char_id

			order by bookmark_id asc;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_bookmarkda_srchbookmarkbycharid;
-- +goose StatementEnd
