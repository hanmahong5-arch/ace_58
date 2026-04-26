-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPetDAO_ChangePetName.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpetdao_changepetname(_dbid BIGINT, _char_id INTEGER, _name TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
begin tran	

		

		if EXISTS (select forbidden_id from forbidden_word(nolock) where (FORBIDDEN_TYPE=0 and FORBIDDEN_REASON=1 and is_like=0 and forbidden_word=_name) or (FORBIDDEN_TYPE=0 and FORBIDDEN_REASON=1 and is_like=1 and forbidden_word like '%'+ _name +'%'))

		begin

			rollback tran

			return 2

		end

				

		if EXISTS (select id from user_pet(UPDLOCK) where name = _name)

			begin

				rollback tran

				return 1

			end

		else

			begin

				update user_pet set name=_name where id=_dbid and char_id=_char_id

			end		

			

		commit tran						

		return 0;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpetdao_changepetname;
-- +goose StatementEnd
