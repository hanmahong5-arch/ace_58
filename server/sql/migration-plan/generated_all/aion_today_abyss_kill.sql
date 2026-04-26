-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_Today_Abyss_Kill.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_today_abyss_kill()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	DECLARE _temp TABLE

	(

		user_id int,

		user_name NVARCHAR(25),

		user_race int,

		user_kill_cnt int,

		kill_cnt int,	

		from_name NVARCHAR(25),	

		mail_title NVARCHAR(25),

		mail_centent NVARCHAR(255),

		item_id int,

		item_count int

	);

	--大于250奖励

	INSERT INTO _temp(user_id, user_name, user_race, user_kill_cnt, kill_cnt, from_name, mail_title, mail_centent, item_id, item_count)

	select char_id, user_id, race, today_abyss_kill_cnt, 250, N'人头奖励', N'杀死 250 人奖励', N'请查收以下物品', 188051885, 1

	from user_data 

	where today_abyss_kill_cnt >= 250 and DateDiff(dd,last_login_time,NOW())=0

	order by today_abyss_kill_cnt desc;

	--大于200奖励

	INSERT INTO _temp(user_id, user_name, user_race, user_kill_cnt, kill_cnt, from_name, mail_title, mail_centent, item_id, item_count)

	select char_id, user_id, race, today_abyss_kill_cnt, 200, N'人头奖励', N'杀死 200 人奖励', N'请查收以下物品', 186000030, 1

	from user_data 

	where today_abyss_kill_cnt >= 200 and DateDiff(dd,last_login_time,NOW())=0

	order by today_abyss_kill_cnt desc;



	--大于150奖励

	INSERT INTO _temp(user_id, user_name, user_race, user_kill_cnt, kill_cnt, from_name, mail_title, mail_centent, item_id, item_count)

	select char_id, user_id, race, today_abyss_kill_cnt, 150, N'人头奖励', N'杀死 150 人奖励', N'请查收以下物品', 188051720, 1

	from user_data 

	where today_abyss_kill_cnt >= 150 and DateDiff(dd,last_login_time,NOW())=0

	order by today_abyss_kill_cnt desc;



	--大于100奖励

	INSERT INTO _temp(user_id, user_name, user_race, user_kill_cnt, kill_cnt, from_name, mail_title, mail_centent, item_id, item_count)

	select char_id, user_id, race, today_abyss_kill_cnt, 100, N'人头奖励', N'杀死 100 人奖励', N'请查收以下物品', 186000031, 1

	from user_data 

	where today_abyss_kill_cnt >= 100 and DateDiff(dd,last_login_time,NOW())=0

	order by today_abyss_kill_cnt desc;



	--大于50奖励

	INSERT INTO _temp(user_id, user_name, user_race, user_kill_cnt, kill_cnt, from_name, mail_title, mail_centent, item_id, item_count)

	select char_id, user_id, race, today_abyss_kill_cnt, 50, N'人头奖励', N'杀死 50 人奖励', N'请查收以下物品', 186000051, 1

	from user_data 

	where today_abyss_kill_cnt >= 50 and DateDiff(dd,last_login_time,NOW())=0

	order by today_abyss_kill_cnt desc;



	select * from _temp order by user_kill_cnt desc



	DECLARE

		_user_id AS INT,

		_user_name AS NVARCHAR(20),

		_user_race AS INT,

		_user_kill_cnt AS INT,

		_kill_cnt  AS INT,

		_from_name AS NVARCHAR(25),	

		_mail_title AS NVARCHAR(25),

		_mail_centent AS NVARCHAR(255),

		_item_id AS INT,

		_item_count AS INT;

	    



	WHILE EXISTS(SELECT user_name FROM _temp)

	BEGIN

		SET ROWCOUNT 1



		SELECT user_id, _user_name= user_name, _user_race= user_race,_user_kill_cnt= user_kill_cnt,_kill_cnt= kill_cnt,_from_name= from_name,_mail_title= mail_title,_mail_centent= mail_centent,_item_id= item_id,_item_count= item_count INTO _user_id FROM _temp;



		DECLARE _string NVARCHAR(512)



		_string := 'EXEC aion_SendMailItem N'''+_user_name+''', N'''+ _from_name +''', N'''+_mail_title+''', N'''+_mail_centent+''', '+convert(NVARCHAR,_item_id)+', '+convert(NVARCHAR,_item_count)+', 0'

	     

		if exists (select char_id from user_data where user_id = _user_name)

			EXEC(_string)

		else
RAISE NOTICE '%', _string;



		SET ROWCOUNT 0

	    

		DELETE FROM _temp WHERE user_name=_user_name and item_id=_item_id  and kill_cnt=_kill_cnt;

	END




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_today_abyss_kill;
-- +goose StatementEnd
