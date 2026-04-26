-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutHouseScriptFieldToInstant.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_puthousescriptfieldtoinstant(_addr_id INTEGER, _char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: CLOSE
-- TODO: unsupported T-SQL construct: DEALLOCATE


BEGIN




	DECLARE _slot_id INT;

	DECLARE _script_size SMALLINT;

	DECLARE _script_data VARBINARY(3072);



	DECLARE script_cursor CURSOR FOR (SELECT slot_id, script_size, script_data FROM house_field_script WHERE addr_id = _addr_id);

	OPEN script_cursor;

	FETCH NEXT FROM script_cursor INTO _slot_id, _script_size, _script_data;

	WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

	BEGIN

		EXEC aion_SetHouseInstantScript _char_id, _slot_id, _script_size, _script_data;

		FETCH NEXT FROM script_cursor INTO _slot_id, _script_size, _script_data;

	END

	CLOSE script_cursor;

	DEALLOCATE script_cursor;



	DELETE FROM house_field_script WHERE addr_id = _addr_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthousescriptfieldtoinstant;
-- +goose StatementEnd
