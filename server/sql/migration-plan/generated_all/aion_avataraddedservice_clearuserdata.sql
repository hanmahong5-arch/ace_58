-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AvatarAddedService_ClearUserData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_avataraddedservice_clearuserdata(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _rowcnt int

	_rowcnt := 0

	

	DELETE FROM vendor_item_dark where char_id = _char_id

	_rowcnt := _rowcnt + @_r_o_w_c_o_u_n_t

	

	DELETE FROM vendor_item_light where char_id = _char_id

	_rowcnt := _rowcnt + @_r_o_w_c_o_u_n_t



	update	user_item 

	set		warehouse = 0

	output	NOW(), inserted.char_id, inserted.id, deleted.warehouse, inserted.warehouse

	into	AvatarAddedService_ClearVendorLog

	where	char_id = _char_id and warehouse = 4

	_rowcnt := _rowcnt + @_r_o_w_c_o_u_n_t

	

	update	user_data

	set		guild_id = 0, guild_rank = 0

	where	char_id = _char_id

	_rowcnt := _rowcnt + @_r_o_w_c_o_u_n_t

	

	select _rowcnt as rowcnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_avataraddedservice_clearuserdata;
-- +goose StatementEnd
