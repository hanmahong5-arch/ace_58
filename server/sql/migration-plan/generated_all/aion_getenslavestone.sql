-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetEnslaveStone.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getenslavestone(_id BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT status, monsterClass, lev, exp

FROM user_item_enslave_stone

WHERE id=_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getenslavestone;
-- +goose StatementEnd
