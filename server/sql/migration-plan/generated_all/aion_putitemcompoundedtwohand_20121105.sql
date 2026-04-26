-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutItemCompoundedTwoHand_20121105.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putitemcompoundedtwohand_20121105(_id BIGINT, _main_item_dbid BIGINT, _warehouse INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
declare _ret int



update user_item 

set warehouse = _warehouse,  main_item_dbid = _main_item_dbid, update_date=NOW()

where id = _id and warehouse != 17   /* 17은 합성제거된 아이템,  합성제거된 아이템이 다시 합성되지는 않음 */



_ret := @_r_o_w_c_o_u_n_t



declare _charid int



if NOT EXISTS (select id  from user_item_option where id = _id) 

begin

	SELECT char_id INTO _charid from user_item where id = _id

	insert into user_item_option (id, char_id) values (_id, _charid)

end




IF @_e_r_r_o_r <> 0

	return _ret

	

_id := @_i_d_e_n_t_i_t_y



return _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putitemcompoundedtwohand_20121105;
-- +goose StatementEnd
