-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_LunaInfoListDA_SrchLunaAbyssBoostOnByCharId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_lunainfolistda_srchlunaabyssboostonbycharid(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	abyss_id, is_boost_on

	FROM	user_luna_abyss_boost (nolock)

	WHERE	char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_lunainfolistda_srchlunaabyssboostonbycharid;
-- +goose StatementEnd
