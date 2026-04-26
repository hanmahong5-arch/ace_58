-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_setitemprocbreakcount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemprocbreakcount(_dbid BIGINT, _proc_count INTEGER, _proc_flag INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin

	update user_item_option set proc_break_count = _proc_count, proc_break_flag = _proc_flag where id = _dbid

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemprocbreakcount;
-- +goose StatementEnd
