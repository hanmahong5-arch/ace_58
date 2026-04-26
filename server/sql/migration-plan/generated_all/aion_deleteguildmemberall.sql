-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteGuildMemberAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteguildmemberall(_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_data  

	SET guild_id=0, guild_rank=0, guild_intro='',guild_update_date = NOW()

    FROM 

     (

         SELECT guild_id,char_id FROM user_data  with(nolock)

         WHERE guild_id = _guild_id  

      )a

     inner LOOP join  user_data    b

     on a.char_id=b.char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteguildmemberall;
-- +goose StatementEnd
