-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ChargeCharRace.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_chargecharrace(_account TEXT, _race INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

  if object_id('tempdb..#tempcharid') is not null Begin

     drop table #tempcharid

  End

	CREATE TABLE #tempcharid (

	pid int identity(1,1),

	accountId int,

	charId int,

	charName nvarchar(20),

	classId tinyint

	)


	declare _n int

	declare _rows int

	_n := 1

	INSERT INTO #tempcharid (accountId, charId, charName, classId) SELECT account_id, char_id, user_id, class FROM user_data 

	WHERE account_name = _account

	SELECT count(*) INTO _rows FROM #tempcharid

	WHILE _n <= _rows

	BEGIN

	   DECLARE _char_id int

		 DECLARE _account_id int

	   DECLARE _char_name nvarchar(20)

	   DECLARE _class tinyint

	   SELECT _account_id = accountId, _char_id = charId, _char_name = charName, _class = classId FROM #tempcharid WHERE pid = _n

	   IF(_char_id != 0)

	   BEGIN

	      IF(_class = 1 OR _class = 2) BEGIN

		    _class := 0

		 END

		 IF(_class = 4 OR _class = 5) BEGIN

		    _class := 3

		 END

		 IF(_class = 7 OR _class = 8) BEGIN

		    _class := 6

		 END

		 IF(_class = 10 OR _class = 11) BEGIN

		    _class := 9

		 END

		 IF(_class = 13 OR _class = 14) BEGIN

		    _class := 12

		 END

		 IF(_class = 16 OR _class = 17) BEGIN

		    _class := 15

		 END

	   UPDATE abyss_ranking SET race = _race WHERE char_id = _char_id

	   IF (_race = 0)

	   BEGIN

	       DELETE FROM user_quest WHERE char_id = _char_id

				 DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 1006

			   DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 2945

			   DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 2008

			   DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 1920

	       UPDATE user_finished_quest SET quest_id = 1000 WHERE quest_id = 2000 AND char_id = _char_id

		     UPDATE user_finished_quest SET quest_id = 21226 WHERE quest_id = 11205 AND char_id = _char_id

			   UPDATE user_finished_quest SET quest_id = 21230 WHERE quest_id = 11220 AND char_id = _char_id

			   UPDATE user_finished_quest SET quest_id = 21233 WHERE quest_id = 11064 AND char_id = _char_id

			   UPDATE user_finished_quest SET quest_id = 21235 WHERE quest_id = 11067 AND char_id = _char_id

				 UPDATE user_finished_quest SET quest_id = 25690 WHERE quest_id = 15690 AND char_id = _char_id

		     UPDATE user_data 

	       SET race = _race, class = _class, lev = 1, world = 210010000, xlocation = 871, ylocation = 1190, zlocation = 112,

	          last_normal_world = 210010000, last_normal_xlocation = 871, last_normal_ylocation = 1190, last_normal_zlocation = 112,

	          resurrect_world = 210010000, resurrect_xlocation = 871, resurrect_ylocation = 1190, resurrect_zlocation = 112, guild_id = 0

	       WHERE char_id = _char_id

		     DELETE FROM user_item where char_id = _char_id AND name_id = 186000005

			   DELETE FROM user_item where char_id = _account_id AND name_id = 186000005

		     UPDATE user_item set warehouse = 6 where warehouse = 7 AND char_id = _account_id

	   END

	   ELSE

	   IF (_race = 1)

	   BEGIN

		     DELETE FROM user_quest WHERE char_id = _char_id

		     DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 1006

			   DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 2945

				 DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 2008

			   DELETE FROM user_finished_quest WHERE char_id = _char_id AND quest_id = 1920

	       UPDATE user_finished_quest SET quest_id = 2000 WHERE quest_id = 1000 AND char_id = _char_id

		     UPDATE user_finished_quest SET quest_id = 11205 WHERE quest_id = 21226 AND char_id = _char_id

			   UPDATE user_finished_quest SET quest_id = 11220 WHERE quest_id = 21230 AND char_id = _char_id

			   UPDATE user_finished_quest SET quest_id = 11064 WHERE quest_id = 21233 AND char_id = _char_id

			   UPDATE user_finished_quest SET quest_id = 11067 WHERE quest_id = 21235 AND char_id = _char_id

				 UPDATE user_finished_quest SET quest_id = 15690 WHERE quest_id = 25690 AND char_id = _char_id

		     UPDATE user_data 

	       SET race = _race, class = _class, lev = 1, world = 220010000, xlocation = 593, ylocation = 2464, zlocation = 280,

	         last_normal_world = 220010000, last_normal_xlocation = 593, last_normal_ylocation = 2464, last_normal_zlocation = 280,

	         resurrect_world = 220010000, resurrect_xlocation = 593, resurrect_ylocation = 2464, resurrect_zlocation = 280, guild_id = 0

	       WHERE char_id = _char_id

				 DELETE FROM user_item where char_id = _char_id AND name_id = 186000010

				 DELETE FROM user_item where char_id = _account_id AND name_id = 186000010

			   UPDATE user_item set warehouse = 7 where warehouse = 6 AND char_id = _account_id

	   END

		 INSERT INTO user_skill_backup1 SELECT * FROM user_skill WHERE char_id = _char_id AND skill_id >= 30000

	   DELETE FROM user_skill WHERE char_id = _char_id

	   DECLARE _dbid bigint

	   INSERT INTO user_item (char_id,name_id,amount,slot,warehouse) VALUES (_char_id,188900001, 30, '0', 5)

	   _dbid := @_i_d_e_n_t_i_t_y;

	   INSERT INTO user_item_option (id, char_id, enchant_count, authorize_count, skin_name_id) VALUES (_dbid, _char_id, 0, 0, 188900001)

	   INSERT INTO user_mail (to_id,to_name,from_id,from_name,title,content,item_id,item_nameid,item_amount, express_mail) 

	   VALUES (_char_id, _char_name, 0, N'系统邮件',N'转换种族', N'转种族补发升级药水', _dbid, 188900001, 30, 0)

		 DECLARE _dbid1 bigint

	   INSERT INTO user_item (char_id,name_id,amount,slot,warehouse)

	   VALUES (_char_id,169650000, 1, '0', 5)

	   _dbid1 := @_i_d_e_n_t_i_t_y;

	   INSERT INTO user_item_option (id, char_id, enchant_count, authorize_count, skin_name_id)

	   VALUES (_dbid1, _char_id, 0, 0, 169650000)

	   INSERT INTO user_mail (to_id,to_name,from_id,from_name,title,content,item_id,item_nameid,item_amount, express_mail) 

	   VALUES (_char_id, _char_name, 0, N'系统邮件',N'转换种族', N'转种族补发外貌变更', _dbid, 169650000, 1, 0)

	   END

	   _n := _n+1

	END


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_chargecharrace;
-- +goose StatementEnd
