-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MoveToLegacyAllUserData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_movetolegacyalluserdata(_ncount INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: DEALLOCATE
-- TODO: unsupported T-SQL construct: TRY


BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	BEGIN TRAN

	

	DECLARE	   _table_name					nvarchar(50)

	DECLARE    _legacytbl					nvarchar(70)

	DECLARE    _column_name					nvarchar(50)

	DECLARE    _id_for_offset				bigint

	

	IF EXISTS (SELECT object_id FROM sys.tables WHERE name = 'temp_user_id_object$')

		DROP TABLE temp_user_id_object$



	DECLARE		_sql		nvarchar(4000)

	_sql := 'SELECT TOP ' + CAST(_ncount AS nvarchar(50)) + ' char_id INTO temp_user_id_object$ FROM user_data WHERE delete_complete_date <> 0 AND delete_complete_date + 3600*24*90 < GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0)'
RAISE NOTICE '%', _sql;

	EXEC sp_executesql _sql

	

	insert legacy_log(legacy_date, legacy_count) values(NOW(), _ncount)	

	_id_for_offset := SCOPE_IDENTITY()

	

	

	-- 같은 이름의 legacy_table이 있는지 체크만

	DECLARE check_item CURSOR

	FOR

	SELECT table_name, column_name_of_charid FROM legacy_user_tables

	OPEN check_item

	FETCH NEXT FROM check_item INTO _table_name, _column_name

	WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

	BEGIN

		_legacytbl := 'legacy_'+ CAST(_id_for_offset AS nvarchar(20))+ '_' + _table_name

		

		IF EXISTS (SELECT object_id FROM sys.tables WHERE name = _legacytbl)

		BEGIN
RAISE NOTICE '%', 'Error! Legacy table is exist. Try again!!';

			RETURN 1

		END

		FETCH NEXT FROM check_item INTO _table_name, _column_name

	END

	CLOSE		check_item

	DEALLOCATE	check_item		

	

	

	DECLARE cur_item CURSOR

	FOR

	SELECT table_name, column_name_of_charid FROM legacy_user_tables

	

	OPEN cur_item

	FETCH NEXT FROM cur_item INTO _table_name, _column_name



	WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

	BEGIN

	

		_legacytbl := 'legacy_'+ CAST(_id_for_offset AS nvarchar(20))+ '_' + _table_name

		

		IF EXISTS (SELECT object_id FROM sys.tables WHERE name = _table_name)

		BEGIN 

			_sql := 'SELECT * INTO ' + _legacytbl + ' FROM ' + _table_name + ' WHERE ' + _column_name + ' IN (SELECT char_id FROM temp_user_id_object$)'

			IF _table_name = 'user_item'

			BEGIN

				_sql := 'SELECT * INTO ' + _legacytbl + ' FROM ' + _table_name + ' WHERE (warehouse <> 3 AND warehouse <> 6 AND warehouse <> 7) AND ' + _column_name + ' IN (SELECT char_id FROM temp_user_id_object$)'

			END
RAISE NOTICE '%', _sql;

			EXEC sp_executesql _sql



			_sql := 'DELETE FROM ' + _table_name + ' WHERE ' + _column_name + ' IN (SELECT char_id FROM temp_user_id_object$)'

			IF _table_name = 'user_item'

			BEGIN

				_sql := 'DELETE FROM ' + _table_name + ' WHERE (warehouse <> 3 AND warehouse <> 6 AND warehouse <> 7) AND ' + _column_name + ' IN (SELECT char_id FROM temp_user_id_object$)'

			END
RAISE NOTICE '%', _sql;

			EXEC sp_executesql _sql

			

			insert into legacy_table_list(log_id, table_name, result) values(_id_for_offset, _legacytbl, 1)

		END

		ELSE

		BEGIN

			insert into legacy_table_list(log_id, table_name, result) values(_id_for_offset, _legacytbl, 0)

		END

		

		FETCH NEXT FROM cur_item INTO _table_name, _column_name

	END

	CLOSE		cur_item

	DEALLOCATE	cur_item	





	DROP TABLE temp_user_id_object$

	

	COMMIT TRAN

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_movetolegacyalluserdata;
-- +goose StatementEnd
