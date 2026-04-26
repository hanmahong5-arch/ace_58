-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFamiliarInfo_20180226.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfamiliarinfo_20180226(_id BIGINT, _master_id INTEGER, _slot1 INTEGER, _slot2 INTEGER, _slot3 INTEGER, _slot4 INTEGER, _slot5 INTEGER, _slot6 INTEGER, _looting_state INTEGER, _growth_point INTEGER, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




UPDATE user_familiar

SET slot1 = _slot1, slot2 = _slot2, slot3 = _slot3, slot4 = _slot4, slot5 = _slot5, slot6 = _slot6,

looting_state = _looting_state, growth_point = _growth_point, update_time = _update_time

WHERE id = _id AND char_id = _master_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfamiliarinfo_20180226;
-- +goose StatementEnd
