-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutMoveChar.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putmovechar(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	insert user_server_transfer(char_id, user_state, reg_service_id) values(_char_id, -1, 0)



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putmovechar;
-- +goose StatementEnd
