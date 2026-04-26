-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutEnslaveStone.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putenslavestone(_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_item_enslave_stone(id, status, monsterClass, lev, exp)

VALUES (_id, 0, 0, 0, 0);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putenslavestone;
-- +goose StatementEnd
