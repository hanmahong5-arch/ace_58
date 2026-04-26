-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetFamiliarList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getfamiliarlist(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




SELECT	id, char_id, base_name_id, cur_name_id, name, evolve_cnt, create_time, update_time, safety_flag, growth_point, slot1, slot2, slot3, slot4, slot5, slot6, looting_state

FROM user_familiar WITH(NOLOCK)

WHERE char_id = _char_id AND deleted != 1




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getfamiliarlist;
-- +goose StatementEnd
