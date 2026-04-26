-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_PutSkillSkin.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutSkillSkin.sql
-- Persists ownership of a cosmetic skill skin (item-shop unlock).
-- T-SQL form is EXISTS-UPDATE-or-INSERT under UPDLOCK; PG uses INSERT…
-- ON CONFLICT DO UPDATE on the (char_id, skill_skin_id) PK.
--
-- T-SQL UPDATE branch sets use_skin = 0 (re-unequipping the skin on re-grant)
-- — preserved here. Client must explicitly re-equip after re-grant.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskillskin(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putskillskin(
    _char_id       INTEGER,
    _skill_skin_id INTEGER,    -- T-SQL smallint widened for client convenience
    _expire_time   INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_skill_skin
        (char_id, skill_skin_id, expire_time, use_skin, update_time)
    VALUES (_char_id, _skill_skin_id::SMALLINT, _expire_time, 0, NOW())
    ON CONFLICT (char_id, skill_skin_id) DO UPDATE SET
        use_skin    = 0,
        expire_time = EXCLUDED.expire_time,
        update_time = NOW();
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putskillskin(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
