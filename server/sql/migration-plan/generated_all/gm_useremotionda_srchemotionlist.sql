-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserEmotionDA_SrchEmotionList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useremotionda_srchemotionlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			select	char_id, emotion_type, expire_date 

			from	USER_EMOTION(nolock)

			where	char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useremotionda_srchemotionlist;
-- +goose StatementEnd
