-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemDye_20111227.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemdye_20111227(_item_id BIGINT, _info INTEGER, _expire_dye_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
declare _char_id int



/*

SELECT char_id INTO _char_id  from user_item_option where id = _item_id

if (_char_id is not null)

begin

	update user_item_option set dye_info = _info, expire_dye_time = _expire_dye_time where ID = _item_id

end

else

begin

	select _char_id = char_id  from user_item where id = _item_id

	insert into user_item_option (id, char_id,dye_info, expire_dye_time) values (_item_id, _char_id, _info, _expire_dye_time)

end




*/




if EXISTS (select id  from user_item_option (UPDLOCK) where id = _item_id) 

	begin

		update user_item_option set dye_info = _info, expire_dye_time = _expire_dye_time where ID = _item_id

	end

else

	begin

		select _char_id = char_id  from user_item where id = _item_id

		insert into user_item_option (id, char_id,dye_info, expire_dye_time) values (_item_id, _char_id, _info, _expire_dye_time)

		if @_e_r_r_o_r <> 0

		begin

			update user_item_option set dye_info = _info, expire_dye_time = _expire_dye_time where ID = _item_id

		end

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemdye_20111227;
-- +goose StatementEnd
