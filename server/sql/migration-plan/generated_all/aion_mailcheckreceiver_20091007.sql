-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailCheckReceiver_20091007.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_mailcheckreceiver_20091007(_receiver TEXT, _sender_id INTEGER, _max INTEGER, _now_time INTEGER, _sender_race INTEGER, _block_option INTEGER, _receive_level INTEGER, _sender_level INTEGER, _sender_guild_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
declare _char_id 	int

declare _count		int

declare _recver_race	tinyint

declare _optionflags	int

_char_id := 0



-- get 수신자 id

SELECT char_id, _recver_race = race, _optionflags = optionflags INTO _char_id

from user_data

where user_id = _receiver and delete_complete_date = 0 and delete_date = 0 order by char_id desc



if (@_rowcount = 0)

begin

	select 1, _char_id		-- 수신자 없음

	return

end



-- useblockoption이 1일 경우에만 아래 코드를 처리한다.

if (_block_option = 1)

begin

	

	if ((_optionflags & 0x01000000) = 0x01000000)

	begin

		-- 친구목록에 있거나 레기온이 같으면 예외

		declare _buddy_check int

		select _buddy_check=char_id from user_buddy1 where char_id = _char_id and buddy_id =_sender_id

		if (_buddy_check <> 0)

		begin

			goto BlockOption_Check_Success

		end			

		else 

		begin			

			if (_sender_guild_id <> 0)

			begin

				declare _receiver_guild_id int

				select _receiver_guild_id=guild_id from user_data where char_id = _char_id 

				if (_sender_guild_id = _receiver_guild_id)

				begin

					goto BlockOption_Check_Success

				end

			end

		end

		select 5, _char_id      -- 스팸 처리

		return		

	end		

	-- minReceiveLevel이하의 Mail은 무시하도록 되어 있다면

	else if ((_optionflags & 0x00800000) = 0x00800000)

	begin		

		if (_sender_level < _receive_level)

	    begin			

			-- 친구목록에 있거나 레기온이 같으면 예외

			declare _buddy_check2 int

			select _buddy_check2=char_id from user_buddy1 where char_id = _char_id and buddy_id =_sender_id

			if (_buddy_check2 <> 0)

			begin

				goto BlockOption_Check_Success

			end			

			else 

			begin				

				if (_sender_guild_id <> 0)

				begin

					declare _receiver_guild_id2 int

					select _receiver_guild_id2=guild_id from user_data where char_id = _char_id 

					if (_sender_guild_id = _receiver_guild_id2)

					begin

						goto BlockOption_Check_Success

					end

				end

			end

			select 6, _char_id      -- 스팸 처리

			return	

		end					

	end	

end



BlockOption_Check_Success:

declare _tmp int

select _tmp=char_id from user_block where char_id = _char_id and block_id =_sender_id

if (_tmp <>0)

begin

	select 4, _char_id      -- 스팸 처리

	return

end





/* 도착예정인 메일도 포함해야 한다. */

select _count = count(*) 

from user_mail

where to_id = _char_id

if (_count >= _max)

begin

	select 2, _char_id		-- mailbox full

	return

end



if (_sender_race = _recver_race)

begin

	select 0, _char_id

	return

end

else

begin

	select 3, _char_id

	return

end /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_mailcheckreceiver_20091007;
-- +goose StatementEnd
