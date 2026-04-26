-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getitem(_user_item_db_id BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted



SELECT   a.id, name_id, slot_id,  amount, tid, slot, COALESCE(soul_bound, 0), COALESCE(enchant_count,0), COALESCE(skin_name_id,0),

	COALESCE(b.stat_enchant_name0, 0), 

	COALESCE(b.stat_enchant_name1, 0), 

	COALESCE(b.stat_enchant_name2, 0), 

	COALESCE(b.stat_enchant_name3, 0), 

	COALESCE(b.stat_enchant_name4, 0), 

	COALESCE(b.stat_enchant_name5, 0), 

	COALESCE(option_count, 0),

	COALESCE(dye_info, 0), COALESCE(proc_tool_nameid, 0), producer, expired_time, buy_amount, buy_duration,

	COALESCE(obtain_skin_type, 0), COALESCE(expire_skin_time, 0), COALESCE(expire_dye_time, 0) AS expire_dye_time,

	COALESCE(random_option, 0) AS random_option,

	COALESCE(limit_enchant_count, 0) AS limit_enchant_count,

	COALESCE(reidentify_count, 0) as reidentify_count,	

	COALESCE(authorize_count, 0) as authorize_count,

	COALESCE(vanish_point, 0) as vanish_point,

	COALESCE(b.enchant_prob_addition, 0),

	COALESCE(b.option_prob_addition, 0)

FROM      user_item a left join  user_item_option b on a.id = b.id

WHERE   (a.id = _user_item_db_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getitem;
-- +goose StatementEnd
