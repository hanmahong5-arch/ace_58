-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemRandomOptionall.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemrandomoptionall(_item_id BIGINT, _random_option INTEGER, _limit_enchant INTEGER, _option_count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item_option SET random_option = _random_option, limit_enchant_count = _limit_enchant, option_count = _option_count  WHERE id = _item_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemrandomoptionall;
-- +goose StatementEnd
