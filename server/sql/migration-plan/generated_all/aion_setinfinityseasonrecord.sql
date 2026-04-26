-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetInfinitySeasonRecord.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setinfinityseasonrecord(_charid INTEGER, _prev INTEGER, _current INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin 

	begin tran

	update user_extra_info set prevSeasonReward = _prev, currentSeasonReward = _current where char_id = _charid

	

	if @_r_o_w_c_o_u_n_t = 0

	begin

		insert into user_extra_info (char_id, use_bot_channel, account_id, vip_icon, prevSeasonReward, currentSeasonReward)

			values (_charid, 0, 0, 0, _prev, _current)

	end

	commit tran

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setinfinityseasonrecord;
-- +goose StatementEnd
