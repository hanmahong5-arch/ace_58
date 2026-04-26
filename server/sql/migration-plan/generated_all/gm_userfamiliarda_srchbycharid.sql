-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFamiliarDA_SrchByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfamiliarda_srchbycharid(_char_id INTEGER, _include_deleted INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


set transaction isolation level read uncommitted



IF _include_deleted = 0

BEGIN

	SELECT	*

	FROM user_familiar(nolock)

	WHERE char_id = _char_id and deleted = 0

END

ELSE

BEGIN

	SELECT	*

	FROM user_familiar(nolock)

	WHERE char_id = _char_id

	ORDER BY deleted

END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfamiliarda_srchbycharid;
-- +goose StatementEnd
