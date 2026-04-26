-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MoveToLegacyItems.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_movetolegacyitems(_ncount INTEGER, _offset INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: DEALLOCATE


BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	DECLARE    _legacytbl	nvarchar(50)

	_legacytbl := 'user_item_legacy_'+ CAST(_offset AS nvarchar(20))

	

	BEGIN TRAN

	

	IF EXISTS (SELECT object_id FROM sys.tables WHERE name = 'temp_item_id_object$')

		DROP TABLE temp_item_id_object$



	DECLARE		_sql		nvarchar(4000)

	_sql := 'SELECT id, char_id INTO temp_item_id_object$ FROM user_item WHERE (warehouse <> 3 AND warehouse <> 6 AND warehouse <> 7) AND char_id IN (SELECT TOP ' + CAST(_ncount AS nvarchar(50)) + ' char_id FROM user_data WHERE delete_complete_date <> 0 AND delete_complete_date + 3600*24*90 < GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) AND item_legacy = 0)'
RAISE NOTICE '%', _sql;

	EXEC sp_executesql _sql

	

    IF NOT EXISTS (SELECT object_id FROM sys.tables WHERE name = _legacytbl)

	BEGIN

		_sql := 'SELECT * INTO ' + _legacytbl + ' FROM user_item WHERE id IN (SELECT id FROM temp_item_id_object$)'
RAISE NOTICE '%', _sql;

		EXEC sp_executesql _sql

		

		UPDATE user_data SET item_legacy = _offset WHERE char_id IN (SELECT char_id FROM temp_item_id_object$ GROUP BY char_id)

		DELETE FROM user_item WHERE id IN (SELECT id FROM temp_item_id_object$)

	END

	ELSE

	BEGIN

		-- sync tbl.

		EXEC aion_SyncItemLegacyTbl _legacytbl

		

		-- check validity

		DECLARE		_ncolumn_org	int

		DECLARE		_ncolumn_leg	int



		SELECT COUNT(*) INTO _ncolumn_org FROM sys.columns WHERE object_id = OBJECT_ID('user_item')

		SELECT _ncolumn_leg = COUNT(*) FROM sys.columns WHERE object_id = OBJECT_ID(_legacytbl)



		IF _ncolumn_org <> _ncolumn_leg

		BEGIN
RAISE NOTICE '%', 'Error! Maybe sync failed.';

			RETURN 1

		END

		

		-- copy and DELETE FROM DECLARE		_columns	nvarchar(1000)

		_columns := ''

			

		-- cursor

		DECLARE		_name		nvarchar(100)



		DECLARE cur_item CURSOR

		FOR

		SELECT ui.name FROM (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('user_item')) AS ui INNER JOIN (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(_legacytbl)) AS ul ON ui.name = ul.name	

		

		OPEN cur_item

		FETCH NEXT FROM cur_item INTO _name



		WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

		BEGIN

			IF _columns <> ''

				_columns := _columns+', '

			_columns := _columns+_name

			FETCH NEXT FROM cur_item INTO _name

		END

		CLOSE		cur_item

		DEALLOCATE	cur_item

		

		_sql := 'INSERT INTO ' + _legacytbl + '(' + _columns + ') SELECT ' + _columns + ' FROM user_item WHERE id IN (SELECT id FROM temp_item_id_object$)'
RAISE NOTICE '%', _sql;

		

		DECLARE		__t_sql		nvarchar(4000)

		__t_sql := 'SET IDENTITY_INSERT ' + _legacytbl + ' ON ' + _sql + ' SET IDENTITY_INSERT ' + _legacytbl + ' OFF'

		EXEC sp_executesql __t_sql

		

		IF @_e_r_r_o_r = 0

		BEGIN

			UPDATE user_data SET item_legacy = _offset WHERE char_id IN (SELECT char_id FROM temp_item_id_object$ GROUP BY char_id)

			DELETE FROM user_item WHERE id IN (SELECT id FROM temp_item_id_object$)

		END

	END

	

	DROP TABLE temp_item_id_object$

	

	COMMIT TRAN

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_movetolegacyitems;
-- +goose StatementEnd
