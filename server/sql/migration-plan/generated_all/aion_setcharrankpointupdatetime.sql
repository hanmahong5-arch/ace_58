-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCharRankPointUpdateTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcharrankpointupdatetime(_rank_id INTEGER, _update_time BIGINT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin

	

	IF EXISTS (SELECT daily_update_time FROM user_rank_update_time WHERE rank_id = _rank_id)

	begin

		UPDATE user_rank_update_time SET daily_update_time = _update_time WHERE rank_id = _rank_id

	end

	ELSE

	begin

		INSERT user_rank_update_time VALUES (_rank_id, _update_time, 0)

	end

		

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcharrankpointupdatetime;
-- +goose StatementEnd
