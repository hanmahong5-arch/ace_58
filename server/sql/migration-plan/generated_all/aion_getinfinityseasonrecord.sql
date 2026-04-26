-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetInfinitySeasonRecord.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinfinityseasonrecord(_charid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin 

select COALESCE(prevSeasonReward, 0), COALESCE(currentSeasonReward, 0) from user_extra_info where char_id = _charid

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinfinityseasonrecord;
-- +goose StatementEnd
