-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteAbnormalStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteabnormalstatus(_char_id INTEGER, _skill_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
DELETE FROM user_abnormal_status

WHERE  char_id=_char_id and skill_id=_skill_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteabnormalstatus;
-- +goose StatementEnd
