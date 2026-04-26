-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutFactionFriendship.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putfactionfriendship(_user_id INTEGER, _faction_id INTEGER, _point INTEGER, _join_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	

	IF EXISTS (SELECT char_id FROM user_faction_friendship(UPDLOCK) WHERE char_id = _user_id AND faction_id = _faction_id)

	BEGIN

		UPDATE user_faction_friendship

		SET jointime = _join_time, friendship = _point

		WHERE char_id = _user_id AND faction_id = _faction_id

	END

	ELSE

	BEGIN

		INSERT user_faction_friendship (char_id, faction_id, friendship, jointime)

		VALUES (_user_id, _faction_id, _point, _join_time)

	END	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfactionfriendship;
-- +goose StatementEnd
