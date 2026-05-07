-- AionCore 5.8 — Sprint 1.1a batch 6 port: aion_GetSkillSkinList (login skill-skin hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetSkillSkinList.sql
-- Original (T-SQL):
--   SELECT  skill_skin_id, expire_time, use_skin
--   FROM user_skill_skin
--   WHERE (char_id = @char_id) AND (expire_time > 0)
--
-- Translation notes:
--   * Skill skins are 5.8 cosmetic re-skins for player skills (e.g. coloured
--     fireballs, alternate animation sets). Owning a skin lets the player toggle
--     `use_skin` to override the default skill VFX.
--   * Per-row state:
--       - skill_skin_id INTEGER  : 5.8 skill_skin catalog id
--       - expire_time   BIGINT   : unix epoch seconds; 0 = expired/inactive (tombstone)
--       - use_skin      SMALLINT : 0=owned-not-equipped, 1=equipped (NCSoft `use_skin` TINYINT)
--   * `expire_time > 0` filter preserved verbatim — same soft-expiry pattern
--     as 00163 (custom_animation): rows with expire_time=0 are tombstones,
--     hidden from the client to keep CS audit trail.
--   * PRIMARY KEY (char_id, skill_skin_id) — a skin is owned at most once.
--   * Function declared STABLE.
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  -- skill-skin hydration on login

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_skill_skin (
    char_id       INTEGER  NOT NULL,
    skill_skin_id INTEGER  NOT NULL,
    expire_time   BIGINT   NOT NULL DEFAULT 0,
    use_skin      SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (char_id, skill_skin_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_skill_skin_char ON user_skill_skin(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskillskinlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getskillskinlist(_char_id INTEGER)
RETURNS TABLE (
    skill_skin_id INTEGER,
    expire_time   BIGINT,
    use_skin      SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT uss.skill_skin_id, uss.expire_time, uss.use_skin
          FROM user_skill_skin uss
         WHERE uss.char_id     = _char_id
           AND uss.expire_time > 0
         ORDER BY uss.skill_skin_id ASC;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getskillskinlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_skill_skin_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_skill_skin;
-- +goose StatementEnd
