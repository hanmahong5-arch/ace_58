-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharGlobalTournamentInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharglobaltournamentinfo()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin 

	select 

	a.char_id,

	b.guild_id,

	a.global_tnmt_apply_seq

	from user_data_ext as a, user_data as b with(nolock) 

	where a.global_tnmt_apply_seq > 0 and a.char_id = b.char_id

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharglobaltournamentinfo;
-- +goose StatementEnd
