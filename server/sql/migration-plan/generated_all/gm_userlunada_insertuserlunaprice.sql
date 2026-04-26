-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserLunaDA_InsertUserLunaPrice.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userlunada_insertuserlunaprice(_char_id INTEGER, _luna_id INTEGER, _use_count INTEGER, _reset_type INTEGER, _reset_week_value INTEGER, _reset_time_value INTEGER, _create_time BIGINT, _update_time TIMESTAMPTZ)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT	user_luna_price (char_id, luna_id, use_count, reset_type, reset_week_value, reset_time_value, create_time, update_time)

	VALUES	(_char_id, _luna_id, _use_count, _reset_type, _reset_week_value, _reset_time_value, _create_time, _update_time);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userlunada_insertuserlunaprice;
-- +goose StatementEnd
