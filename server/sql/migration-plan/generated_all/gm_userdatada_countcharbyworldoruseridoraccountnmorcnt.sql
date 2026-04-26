-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_CountCharByWorldorUserIDorAccountNMorCnt.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_countcharbyworldoruseridoraccountnmorcnt(_user_id TEXT, _account_name TEXT, _builder TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql



			set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			declare _sql nvarchar(1000), _tmp int

						

			_sql := ' select count(char_id) cnt ' +

					   ' from user_data (nolock) '

					   

			_tmp := 0

			

			IF _user_id != 'null'

			BEGIN

				_sql := _sql + ' WHERE user_id like '''+_user_id+''''

				_tmp := 1

			END 

				

			IF _account_name IS NOT NULL

			BEGIN

				IF _tmp = 1

					_sql := _sql + ' AND account_name like '''+_account_name+''''

				ELSE

					BEGIN

						_sql := _sql + ' WHERE account_name like '''+_account_name+''''					

						_tmp := 1

					END

			END

			

			IF _builder IS NOT NULL

			BEGIN

				IF _builder = 95

					BEGIN

						IF _tmp = 1

							_sql := _sql + ' AND builder > ''0'' '

						ELSE

							BEGIN

								_sql := _sql + ' WHERE builder > ''0'' '

								_tmp := 1

							END

					END

				ELSE

					BEGIN

						IF _tmp = 1

							_sql := _sql + ' AND builder = '''+_builder+''''

						ELSE

							BEGIN

								_sql := _sql + ' WHERE builder = '''+_builder+''''					

								_tmp := 1

							END

					END				

			END

								

			exec Sp_ExecuteSQL _sql

			


			return;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_countcharbyworldoruseridoraccountnmorcnt;
-- +goose StatementEnd
