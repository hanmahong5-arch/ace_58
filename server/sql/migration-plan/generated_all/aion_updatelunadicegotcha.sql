-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateLunaDiceGotcha.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatelunadicegotcha(_char_id INTEGER, _open_num INTEGER, _use_special_dice INTEGER, _recv_reward_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin	


	begin tran



	update user_luna_dice_gotcha 

	set open_num = _open_num, use_special_dice = _use_special_dice, recv_reward_time = _recv_reward_time 

	where char_id = _char_id



	if @_r_o_w_c_o_u_n_t = 0

	begin

		insert into user_luna_dice_gotcha (char_id, open_num, use_special_dice, recv_reward_time)

		values (_char_id, _open_num, _use_special_dice, _recv_reward_time)

	end



	commit tran


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatelunadicegotcha;
-- +goose StatementEnd
