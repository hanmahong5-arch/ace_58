-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutQinaManipulate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putqinamanipulate()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
int,

	_char_id as int,

	_warehouse_type as smallint,

	_previous_qina as bigint,

	_current_qina as bigint

as


insert into qina_manipulate 

values (_acct_id, _char_id, _warehouse_type, _previous_qina, _current_qina, NOW());
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putqinamanipulate;
-- +goose StatementEnd
