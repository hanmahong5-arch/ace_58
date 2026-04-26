-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ClearPetitionWebNotify.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearpetitionwebnotify(_char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	delete from user_petition_web where char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearpetitionwebnotify;
-- +goose StatementEnd
