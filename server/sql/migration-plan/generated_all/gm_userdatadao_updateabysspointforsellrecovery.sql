-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_UpdateAbyssPointForSellRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_updateabysspointforsellrecovery(_char_id INTEGER, _used_abysspoint BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_data set abyss_point -= _used_abysspoint where char_id=_char_id and abyss_point >= _used_abysspoint;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_updateabysspointforsellrecovery;
-- +goose StatementEnd
