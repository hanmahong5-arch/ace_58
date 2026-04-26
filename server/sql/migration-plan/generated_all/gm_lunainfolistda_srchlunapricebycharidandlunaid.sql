-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_LunaInfoListDA_SrchLunaPriceByCharIdAndLunaId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_lunainfolistda_srchlunapricebycharidandlunaid(_char_id INTEGER, _luna_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time, update_time

	FROM	user_luna_price (nolock)

	WHERE	char_id = _char_id AND luna_id = _luna_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_lunainfolistda_srchlunapricebycharidandlunaid;
-- +goose StatementEnd
