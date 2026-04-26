-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchCheckVendorItems.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchcheckvendoritems(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			SELECT id from vendor_item_light with (nolock) where char_id = _char_id

			union all

			select top 1 id from vendor_item_dark with (nolock) where char_id = _char_id

			union all

			select top 1 id from vendor_log_light with (nolock) where char_id = _char_id

			union all

			select top 1 id from vendor_log_dark with (nolock) where char_id = _char_id

			


			return /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchcheckvendoritems;
-- +goose StatementEnd
