-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserCustomAnimationDA_SrchCustomAnimation.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usercustomanimationda_srchcustomanimation(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

BEGIN



	SELECT	char_id, animation_id, animation_type, useState, expire_time 

	FROM	user_customAnimation (nolock)

	WHERE	char_id = _char_id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usercustomanimationda_srchcustomanimation;
-- +goose StatementEnd
