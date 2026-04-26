-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_GetVendorCollectibleGoldLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_getvendorcollectiblegoldlight(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	SELECT COALESCE(SUM(sold_price), 0), COALESCE(SUM(after_fee), 0), COALESCE(SUM(after_tax), 0)

	FROM vendor_log_light

	WHERE (char_id = _char_id)

	


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_getvendorcollectiblegoldlight;
-- +goose StatementEnd
