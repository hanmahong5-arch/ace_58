-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_UpdateMoneyForBuyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_updatemoneyforbuyrecovery(_char_id INTEGER, _used_money BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_item set amount += _used_money where char_id=_char_id and warehouse=0 and name_id=182400001;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_updatemoneyforbuyrecovery;
-- +goose StatementEnd
