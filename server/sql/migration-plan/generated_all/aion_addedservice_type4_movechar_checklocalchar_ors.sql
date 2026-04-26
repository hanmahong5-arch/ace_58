-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddedService_Type4_MoveChar_CheckLocalChar_ORS.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addedservice_type4_movechar_checklocalchar_ors(_from_uid INTEGER, _from_race INTEGER, _ret INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
_ret := 0



declare _char_count int

declare _count int

_count := 0



SELECT count(*) INTO _count from user_data (nolock) where account_id = _from_uid and delete_complete_date = 0 and race <> _from_race

if _count <> 0

begin 

	_ret := -10002	-- 복수 Race	

end



_char_count := 0;

_char_count := (select count(*)

					from user_data with (nolock)

					where account_id = _from_uid and delete_complete_date = 0)



if _char_count >= 10

	_ret := -10018	-- 캐릭터 생성 제한 숫자를 초과;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addedservice_type4_movechar_checklocalchar_ors;
-- +goose StatementEnd
