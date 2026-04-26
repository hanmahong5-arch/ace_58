-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetPromotionCooltime_0724.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpromotioncooltime_0724(_char_id INTEGER, _promotion_id INTEGER, _last_promotion_time INTEGER, _received_item_count INTEGER, _cycle_received_item_count INTEGER, _cycle_next_reset_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (SELECT promotion_id FROM user_promotion_cooltime(UPDLOCK) WHERE char_id=_char_id and promotion_id=_promotion_id) 

begin

	UPDATE user_promotion_cooltime

	SET last_promotion_time = _last_promotion_time, received_item_count = _received_item_count, cycle_received_item_count = _cycle_received_item_count, cycle_next_reset_time = _cycle_next_reset_time	

	WHERE char_id=_char_id and promotion_id=_promotion_id

end

else

begin

	INSERT user_promotion_cooltime(char_id, promotion_id, last_promotion_time, received_item_count, cycle_received_item_count, cycle_next_reset_time) 

	VALUES (_char_id, _promotion_id, _last_promotion_time, _received_item_count, _cycle_received_item_count, _cycle_next_reset_time)	

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpromotioncooltime_0724;
-- +goose StatementEnd
