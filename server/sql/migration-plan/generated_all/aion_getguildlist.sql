-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetGuildList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getguildlist(_type INTEGER, _search_string TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	

	if _type = 0		

	begin

	SELECT aa.id, aa.name, bb.user_id, aa.level, aa.memberCount, aa.intro, aa.join_process_type, aa.join_restrict_level FROM

		(

			(SELECT a.id, a.name, a.master_id, a.level, b.memberCount, a.join_process_type, a.join_restrict_level, a.intro, a.point FROM

				(

				(SELECT id, name, master_id, level, join_process_type, join_restrict_level, intro, point  FROM guild WITH(NOLOCK) ORDER BY point DESC) a

				JOIN

				(SELECT COUNT(char_id) as memberCount, guild_id FROM user_data WITH(NOLOCK) WHERE guild_id != 0 and delete_complete_date = 0 GROUP BY guild_id) b

				ON a.id = b.guild_id

				)

			) aa

			JOIN

			(SELECT char_id, user_id FROM user_data WITH(NOLOCK) WHERE guild_id != 0 and delete_complete_date = 0) bb

			ON aa.master_id = bb.char_id

		) ORDER BY aa.point DESC

	end

	else if _type = 1

	begin

	SELECT aa.id, aa.name, bb.user_id, aa.level, aa.memberCount, aa.intro, aa.join_process_type, aa.join_restrict_level FROM

		(

			(SELECT a.id, a.name, a.master_id, a.level, b.memberCount, a.join_process_type, a.join_restrict_level, a.intro FROM

				(

				(SELECT TOP 50 id, name, master_id, level, join_process_type, join_restrict_level, intro  FROM guild WITH(NOLOCK) WHERE name LIKE '%'+_search_string+'%' ORDER BY LEN(name)) a

				JOIN

				(SELECT COUNT(char_id) as memberCount, guild_id FROM user_data WITH(NOLOCK) WHERE guild_id != 0 and delete_complete_date = 0 GROUP BY guild_id) b

				ON a.id = b.guild_id

				)

			) aa

			JOIN

			(SELECT char_id, user_id FROM user_data WITH(NOLOCK) WHERE guild_id != 0 and delete_complete_date = 0) bb

			ON aa.master_id = bb.char_id

		) ORDER BY LEN(aa.name)

	end

	else if _type = 2

	begin

	SELECT aa.id, aa.name, bb.user_id, aa.level, aa.memberCount, aa.intro, aa.join_process_type, aa.join_restrict_level FROM

		(

			(SELECT a.id, a.name, a.master_id, a.level, b.memberCount, a.join_process_type, a.join_restrict_level, a.intro FROM

				(

				(SELECT TOP 50 id, name, master_id, level, join_process_type, join_restrict_level, intro FROM guild WITH(NOLOCK) WHERE intro LIKE '%'+_search_string+'%') a

				JOIN

				(SELECT COUNT(char_id) as memberCount, guild_id FROM user_data WITH(NOLOCK) WHERE guild_id != 0 and delete_complete_date = 0 GROUP BY guild_id) b

				ON a.id = b.guild_id

				)

			) aa

			JOIN

			(SELECT char_id, user_id FROM user_data WITH(NOLOCK) WHERE guild_id != 0 and delete_complete_date = 0) bb

			ON aa.master_id = bb.char_id

		)

	end

END /* LIMIT 50 appended */ LIMIT 50;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getguildlist;
-- +goose StatementEnd
