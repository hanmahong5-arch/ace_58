-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_AbyssDA_SrchCharAbyssDefender.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_abyssda_srchcharabyssdefender(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			SELECT abyss_id, defender_share_amount, defender_rank, update_time

			from abyss_user_defender (nolock)

			where defender_char_id=_char_id order by update_time desc

			
 /* LIMIT 300 appended */ LIMIT 300;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_abyssda_srchcharabyssdefender;
-- +goose StatementEnd
