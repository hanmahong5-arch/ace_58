-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetEnslaveStone.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setenslavestone(_id BIGINT, _status INTEGER, _monster_class INTEGER, _level INTEGER, _exp BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item_enslave_stone

SET status=_status, monsterClass=_monster_class, lev=_level, exp=_exp

WHERE id=_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setenslavestone;
-- +goose StatementEnd
