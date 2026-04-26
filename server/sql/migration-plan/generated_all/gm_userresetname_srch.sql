-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserResetName_Srch.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userresetname_srch(_top_count INTEGER, _page_num INTEGER, _user_id TEXT, _account_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off



			if (_account_id != 0)

			begin

				-- account_id search

				select top (_top_count) account_id, char_id, char_name_old as user_id

				from	reset_charname_list (nolock)

				where	account_id = _account_id

				order by char_name_old



				select count(*) as total from reset_charname_list (nolock)

				where	account_id = _account_id

			end

			else if (COALESCE(_user_id, '') <> '')

			begin

				-- user_id search

				select top (_top_count) account_id, char_id, char_name_old as user_id

				from	reset_charname_list (nolock)

				where	char_id not in (

					select top (_top_count * (_page_num-1)) char_id from reset_charname_list (nolock)

					where	char_name_old like _user_id + '%'

					order	by char_name_old

				)

				and char_name_old like _user_id + '%'



				order by char_name_old



				select count(*) as total from reset_charname_list (nolock) where char_name_old like _user_id + '%'

			end

			else

			begin

				-- search all

				select top (_top_count) account_id, char_id, char_name_old as user_id

				from	reset_charname_list (nolock)

				where	char_id not in (

					select top (_top_count * (_page_num-1)) char_id 

					from	reset_charname_list (nolock) 

					order	by char_name_old

				)

				order by char_name_old



				select count(*) as total from reset_charname_list (nolock)



			end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userresetname_srch;
-- +goose StatementEnd
