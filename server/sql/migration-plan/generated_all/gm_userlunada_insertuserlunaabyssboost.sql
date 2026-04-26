-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserLunaDA_InsertUserLunaAbyssBoost.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userlunada_insertuserlunaabyssboost(_char_id INTEGER, _abyss_id INTEGER, _is_boost_on INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT	user_luna_abyss_boost (char_id, abyss_id, is_boost_on)

	VALUES	(_char_id, _abyss_id, _is_boost_on);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userlunada_insertuserlunaabyssboost;
-- +goose StatementEnd
