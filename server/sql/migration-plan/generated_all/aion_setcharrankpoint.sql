-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharRankPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharrankpoint(_char_id INTEGER, _rank_id INTEGER, _point_to_add INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
begin


	IF EXISTS (SELECT id FROM user_rank WHERE char_id = _char_id AND rank_id = _rank_id)

	begin

		UPDATE user_rank SET point = point + _point_to_add WHERE char_id = _char_id AND rank_id = _rank_id

	end

	ELSE

	begin

		INSERT INTO user_rank(char_id, rank_id, point) VALUES (_char_id, _rank_id, _point_to_add)

	end


end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharrankpoint;
-- +goose StatementEnd
