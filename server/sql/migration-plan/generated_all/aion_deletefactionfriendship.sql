-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteFactionFriendship.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletefactionfriendship(_char_id INTEGER, _faction_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
-- DELETE

-- FROM user_faction_friendship

-- WHERE char_id=_char_id and faction_id=_faction_id

UPDATE user_faction_friendship

SET jointime = 0

WHERE char_id=_char_id and faction_id=_faction_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefactionfriendship;
-- +goose StatementEnd
