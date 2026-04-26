-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CheckPersonalInstantHousingUserRace.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkpersonalinstanthousinguserrace(_user_id INTEGER, _required_quest_light INTEGER, _required_quest_dark INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	declare _quest_count int

	declare _id int

	

	SELECT quest_count INTO _quest_count FROM user_finished_quest WHERE char_id = _user_id AND (quest_id = _required_quest_light OR quest_id = _required_quest_dark)

	IF (0 < (_quest_count))

	BEGIN

		-- valid user personal house available, return state and race

		SELECT _id = id FROM house_field WHERE owner_id = _user_id AND owner_type = 2

		IF (0 < (_id))

		BEGIN

			SELECT 65535, 2, 3;		-- race, state(NO_OWNER), permission(CLOSED)

			RETURN -2;	-- found qualified user, already have field house

		END

		ELSE

		BEGIN

			IF EXISTS (SELECT id FROM house_instant WITH(NOLOCK) WHERE id = _user_id)

			BEGIN

				-- include only state 5

				IF EXISTS (SELECT state FROM house_instant WHERE id = _user_id and state = 5) -- state 5(HSTATE_OCCUPIED)

				BEGIN

					DECLARE _race AS TINYINT

					DECLARE _state AS TINYINT

					DECLARE _permission AS TINYINT

					SELECT race INTO _race FROM user_data WITH(NOLOCK) WHERE char_id = _user_id;

					SELECT state, _permission = permission INTO _state FROM house_instant WITH(NOLOCK) WHERE id = _user_id

					SELECT _race, _state, _permission

					RETURN 0;

				-- RETURN (SELECT state FROM house_instant WHERE id = _user_id);

				END

				ELSE

				BEGIN

					SELECT race, 6, 3 FROM user_data WITH(NOLOCK) WHERE char_id = _user_id	-- race, state(HSTATE_PAY_REQUIRED), permission(HPERMIT_CLOSED)

					RETURN -5; -- pay fee required

				END

			END

			ELSE

			BEGIN

				SELECT race, 5, 1 FROM user_data WITH(NOLOCK) WHERE char_id = _user_id; -- race, state(HSTATE_OCCUPIED), permission(HPERMIT_OPEN)

				RETURN -1;	-- found qualified user, not created house yet

			END

		END

	END

	ELSE

	BEGIN

		SELECT 65535, 2, 3;		-- race, state(NO_OWNER), permission(CLOSED)

		IF EXISTS (SELECT char_id FROM user_data WITH(NOLOCK) WHERE char_id = _user_id)

			RETURN -3;	-- found user, not finished required quest

		ELSE

			RETURN -4;	-- invalid user

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkpersonalinstanthousinguserrace;
-- +goose StatementEnd
