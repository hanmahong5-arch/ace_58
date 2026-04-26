-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteEnslaveStone.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteenslavestone(_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_item_enslave_stone

WHERE id=_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteenslavestone;
-- +goose StatementEnd
