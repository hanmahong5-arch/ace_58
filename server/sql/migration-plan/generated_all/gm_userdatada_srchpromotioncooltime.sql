-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchPromotionCoolTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchpromotioncooltime(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

SELECT promotion_id, last_promotion_time, received_item_count, cycle_received_item_count, cycle_next_reset_time

FROM user_promotion_cooltime

WHERE char_id=_char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchpromotioncooltime;
-- +goose StatementEnd
