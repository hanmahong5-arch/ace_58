-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_UpdateAbyssPointForBuyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_updateabysspointforbuyrecovery(_char_id INTEGER, _used_abysspoint BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_data set abyss_point += _used_abysspoint where char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_updateabysspointforbuyrecovery;
-- +goose StatementEnd
