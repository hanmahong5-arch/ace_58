-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFamiliarDA_Delete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfamiliarda_delete(_familiar_id BIGINT, _char_id INTEGER, _update_time BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_familiar

SET update_time = _update_time, deleted = 1

WHERE id = _familiar_id AND char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfamiliarda_delete;
-- +goose StatementEnd
