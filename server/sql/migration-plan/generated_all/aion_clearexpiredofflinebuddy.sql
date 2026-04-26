-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_clearexpiredofflinebuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearexpiredofflinebuddy()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	delete from user_buddy_offline where DATEDIFF(day, createdate, NOW())> 7


end



/*

	DELETE	

	FROM	user_buddy_offline

	WHERE	createdate < dateadd(day, -7, NOW())

*/;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearexpiredofflinebuddy;
-- +goose StatementEnd
