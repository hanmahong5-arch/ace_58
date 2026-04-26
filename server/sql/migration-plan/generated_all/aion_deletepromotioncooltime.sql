-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeletePromotionCoolTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletepromotioncooltime(_char_id INTEGER, _promotion_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE

FROM user_promotion_cooltime

WHERE char_id=_char_id and promotion_id=_promotion_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletepromotioncooltime;
-- +goose StatementEnd
