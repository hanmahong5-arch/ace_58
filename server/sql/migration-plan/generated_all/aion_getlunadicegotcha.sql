-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetLunaDiceGotcha.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getlunadicegotcha(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	SELECT 

		open_num, 

		use_special_dice,

		recv_reward_time

	FROM 

		user_luna_dice_gotcha 

	WHERE char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getlunadicegotcha;
-- +goose StatementEnd
