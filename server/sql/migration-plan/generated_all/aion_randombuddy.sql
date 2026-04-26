-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_randombuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_randombuddy()
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: CLOSE
-- TODO: unsupported T-SQL construct: DEALLOCATE
 int

as

begin 

	declare _count as int

	declare _buddyid as int

	declare _count1 as int

	declare _count2 as int

	SELECT count(a.buddy_id) INTO _count1 from user_buddy1 a inner join house_field b on buddy_id  = owner_id and permission = 1 where a.char_id = _ownerid 

	select _count2 = count(a.buddy_id) from user_buddy1 a inner join house_instant b on buddy_id  = ID and permission = 1 where a.char_id = _ownerid 	

	

	if _count1 + _count2 = 0

	begin

		return 0;

	end

	

	SELECT (cast(((rand()*100)) as integer)%(_count1 + _count2))

	

	--print _count1

	--print _count2

	--print _count



	declare  buddycursor  cursor for select a.buddy_id INTO _count from user_buddy1 a inner join house_field b on buddy_id  = owner_id and permission = 1 where a.char_id = _ownerid union select a.buddy_id from user_buddy1 a inner join house_instant b on buddy_id  = ID and permission = 1 where a.char_id = _ownerid 	



	_buddyid := 0	

	open buddycursor	

	

	fetch next from buddycursor into _buddyid

	

	while @_f_e_t_c_h__s_t_a_t_u_s = 0

	begin 	

	if _count < 0 break;	

	

	_count := _count - 1

	fetch next from buddycursor into _buddyid

	end

	close buddycursor

	deallocate buddycursor

	--print _buddyid

	return _buddyid;

end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_randombuddy;
-- +goose StatementEnd
