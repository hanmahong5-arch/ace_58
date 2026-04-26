-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetVIPIcon.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setvipicon(_char_id INTEGER, _icon_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update user_extra_info set vip_icon = _icon_id where char_id = _char_id

	

	if @_r_o_w_c_o_u_n_t = 0

		insert into user_extra_info (char_id, use_bot_channel, use_bot_channel_update_date, account_id, vip_Icon) values (_char_id, 0, 0, 0, _icon_id)

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setvipicon;
-- +goose StatementEnd
