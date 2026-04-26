-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_GetHouseOwnerLegionInfo.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_GetHouseOwnerLegionInfo.sql
--
-- Returns the guild_id of the character who owns a given house.
-- Used by housing system to render the legion emblem on the door plate.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseownerlegioninfo(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseownerlegioninfo(_owner_id INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql STABLE AS $$
DECLARE
    _gid INTEGER;
BEGIN
    SELECT guild_id INTO _gid
      FROM user_data
     WHERE char_id = _owner_id;
    RETURN COALESCE(_gid, 0);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseownerlegioninfo(INTEGER);
-- +goose StatementEnd
