-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUserGuildJoinApplicationInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setuserguildjoinapplicationinfo(_char_id INTEGER, _guild_id INTEGER, _applicant_intro TEXT, _apply_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	-- Update user_gp table

	IF EXISTS (SELECT char_id FROM user_guild_join_application WHERE char_id=_char_id)

	BEGIN

		UPDATE user_guild_join_application 

		SET guild_id = _guild_id,

			applicant_intro = _applicant_intro,

			apply_time = _apply_time

		WHERE char_id=_char_id

	END

	ELSE

	BEGIN

		-- table에 추가하는 경우는 guildId가 0이 아닌 경우.

		IF (_guild_id <> 0)

		BEGIN

			INSERT INTO user_guild_join_application (char_id, guild_id, applicant_intro, apply_time) VALUES (_char_id, _guild_id, _applicant_intro, _apply_time)

		END

	END

	


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setuserguildjoinapplicationinfo;
-- +goose StatementEnd
