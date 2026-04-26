-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharLocalTournamentInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharlocaltournamentinfo(_race INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin 

	select 

	a.char_id,

	b.user_id,

	b.lev,

	b.class,

	b.guild_id,

	COALESCE(c.name, ''),

	a.local_tnmt_apply_seq

	from user_data_ext as a, user_data as b left join guild as c on b.guild_id = c.id 

	where a.local_tnmt_apply_seq > 0 

		and a.char_id = b.char_id 

		and b.race = _race

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharlocaltournamentinfo;
-- +goose StatementEnd
