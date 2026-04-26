-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPetDAO_ChangePetMove.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpetdao_changepetmove(_dbid BIGINT, _org_char_id INTEGER, _target_char_id INTEGER, _name_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if EXISTS (select id from user_pet(UPDLOCK) where char_id=_target_char_id and name_id=_name_id )

			begin

				return 1

			end

		else

			begin				

				update user_pet set char_id=_target_char_id where id=_dbid and char_id=_org_char_id

			end

				

		return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpetdao_changepetmove;
-- +goose StatementEnd
