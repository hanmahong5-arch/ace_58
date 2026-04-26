-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMacroDA_SrchMacroIDs.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermacroda_srchmacroids(_char_id TEXT, _slot_ids TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(1000)

						

			_sql := ' select * ' +

					   ' from user_macro (nolock)' +

					   ' where char_id='''+_char_id+''' and ( '

			

			_sql := _sql + _slot_ids + ') '

											

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermacroda_srchmacroids;
-- +goose StatementEnd
