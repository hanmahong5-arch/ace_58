-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteLegacyTables.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletelegacytables(_log_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: DEALLOCATE


BEGIN



	BEGIN TRAN



	DECLARE	   _table_name	nvarchar(50)

	DECLARE		_sql		nvarchar(4000)



	DECLARE cur_item CURSOR

	FOR

	SELECT table_name FROM legacy_table_list WHERE log_id = _log_id 

	

	OPEN cur_item

	FETCH NEXT FROM cur_item INTO _table_name



	WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

	BEGIN

		IF EXISTS (SELECT object_id FROM sys.tables WHERE name = _table_name)

		BEGIN 

			_sql := 'DROP TABLE ' + _table_name
RAISE NOTICE '%', _sql;

			EXEC sp_executesql _sql

		END

		

		FETCH NEXT FROM cur_item INTO _table_name

	END

	CLOSE		cur_item

	DEALLOCATE	cur_item	

	

	DELETE FROM legacy_table_list WHERE log_id = _log_id

	

	--DELETE FROM legacy_log where id = _log_id

	

	COMMIT TRAN

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletelegacytables;
-- +goose StatementEnd
