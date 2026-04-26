-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRankDA_UpdatePoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrankda_updatepoint(_char_id INTEGER, _rank_id INTEGER, _point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


		set transaction isolation level read uncommitted

		set ansi_warnings off



		UPDATE user_rank SET point=_point WHERE char_id=_char_id and rank_id=_rank_id

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrankda_updatepoint;
-- +goose StatementEnd
