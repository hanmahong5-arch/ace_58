-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetFactionFriendship.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setfactionfriendship(_char_id INTEGER, _faction_id INTEGER, _friendship INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_faction_friendship

SET friendship=_friendship

WHERE char_id=_char_id and faction_id=_faction_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setfactionfriendship;
-- +goose StatementEnd
