-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemSlotId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemslotid(_id BIGINT, _slot_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item SET slot_id = _slot_id WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemslotid;
-- +goose StatementEnd
