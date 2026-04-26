-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SyncItemLegacyTbl.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_syncitemlegacytbl(_legacytbl TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: sp_executesql
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: DEALLOCATE


BEGIN


	

	IF EXISTS (SELECT object_id FROM sys.tables WHERE name = 'temp_object$')

		DROP TABLE temp_object$

	

	-- result

	DECLARE		_ret				int

	_ret := 0

	

	CREATE TABLE temp_object$ 

	(

		type_id				int,

		item_id				int,

		legacy_id			int,

		name				nvarchar(100),

		typename			nvarchar(20),

		typesize			int,

		is_nullable			int,

		is_identity			int,

		default_object		int,

		default_string		nvarchar(100)

	)



	INSERT INTO temp_object$(type_id, item_id, legacy_id, name, typename, typesize, is_nullable, is_identity, default_object, default_string) SELECT 0, ui.column_id, 0, ui.name, t.name, ui.max_length, ui.is_nullable, ui.is_identity, ui.default_object_id, GetDefaultConstraintValue(ui.default_object_id) FROM (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('user_item')) AS ui INNER JOIN sys.types AS t ON ui.user_type_id = t.user_type_id WHERE ui.name NOT IN (SELECT name FROM sys.columns WHERE object_id = OBJECT_ID(_legacytbl))



	INSERT INTO temp_object$(type_id, item_id, legacy_id, name, typename, typesize, is_nullable, is_identity, default_object, default_string) SELECT 1, ui.column_id, ul.column_id, ui.name, t.name, ui.max_length, ui.is_nullable, ui.is_identity, ui.default_object_id, GetDefaultConstraintValue(ui.default_object_id) FROM (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('user_item')) AS ui INNER JOIN (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(_legacytbl)) AS ul ON ui.name = ul.name INNER JOIN sys.types AS t ON ui.user_type_id = t.user_type_id

	WHERE	ui.user_type_id <> ul.user_type_id	OR

			ui.max_length <> ul.max_length		

		--	OR

		--	ui.is_nullable <> ul.is_nullable	OR

		--	ui.is_identity <> ul.is_identity	OR

		--	GetDefaultConstraintValue(ui.default_object_id) <> GetDefaultConstraintValue(ul.default_object_id)



	INSERT INTO temp_object$(type_id, item_id, legacy_id, name, typename, typesize, is_nullable, is_identity, default_object, default_string) SELECT 2, 0, ui.column_id, ui.name, t.name, ui.max_length, ui.is_nullable, ui.is_identity, ui.default_object_id, GetDefaultConstraintValue(ui.default_object_id) FROM (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(_legacytbl)) AS ui INNER JOIN sys.types AS t ON ui.user_type_id = t.user_type_id WHERE ui.name NOT IN (SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('user_item'))



	--SELECT * FROM temp_object$



	-- cursor

	DECLARE		_sql				nvarchar(2000)

	DECLARE		_type				nvarchar(100)

	DECLARE		_constraint			nvarchar(200)



	DECLARE		_type_id			int

	DECLARE		_item_id			int

	DECLARE		_legacy_id			int

	DECLARE		_name				nvarchar(100)

	DECLARE		_typename			nvarchar(20)

	DECLARE		_typesize			int

	DECLARE		_is_nullable		int

	DECLARE		_is_identity		int

	DECLARE		_default_object		int

	DECLARE		_default_string		nvarchar(100)



	DECLARE cur_item CURSOR

	FOR

	SELECT type_id, item_id, legacy_id, name, typename, typesize, is_nullable, is_identity, default_object, default_string FROM temp_object$



	OPEN cur_item

	FETCH NEXT FROM cur_item INTO _type_id, _item_id, _legacy_id, _name, _typename, _typesize, _is_nullable, _is_identity, _default_object, _default_string



	WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

	BEGIN

		-- type

		_type := CASE _typename

			WHEN 'nvarchar'			THEN 'nvarchar(' + CAST(_typesize/2 AS nvarchar(10)) + ')'

			WHEN 'varchar'			THEN 'varchar(' + CAST(_typesize AS nvarchar(10)) + ')'

			ELSE					_typename 

			END

		

		-- constraint	

		IF _is_nullable = 0	

			_constraint := 'NOT NULL '

		ELSE 

			_constraint := 'NULL '

		

		IF _default_object <> 0

			_constraint := _constraint+'DEFAULT'+_default_string



		IF _type_id = 0

			_sql := 'ALTER TABLE ' + _legacytbl + ' ADD ' + _name + ' ' + _type + ' ' + _constraint

		ELSE IF _type_id = 1

		BEGIN

			_sql := 'ALTER TABLE ' + _legacytbl + ' ALTER COLUMN ' + _name + ' ' + _type -- + ' ' + _constraint

			-- apply constraint 

		END

	--	ELSE IF _type_id = 2

		--	_sql := 'ALTER TABLE ' + _legacytbl + ' DROP COLUMN ' + _name
RAISE NOTICE '%', _sql;

		

		IF _type_id < 2

		BEGIN

			EXEC sp_executesql _sql

			_ret := @_e_r_r_o_r

		END

		

		FETCH NEXT FROM cur_item INTO _type_id, _item_id, _legacy_id, _name, _typename, _typesize, _is_nullable, _is_identity, _default_object, _default_string

	END

	CLOSE		cur_item

	DEALLOCATE	cur_item



	DROP TABLE temp_object$

	

	IF _ret = 0
RAISE NOTICE '%', 'The legacy tbl has been synchronized.';

	ELSE
RAISE NOTICE '%', 'Error occurred('+ CAST(_ret AS NVARCHAR(30)) +'). Do sync manually.';

	

	RETURN _ret

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_syncitemlegacytbl;
-- +goose StatementEnd
