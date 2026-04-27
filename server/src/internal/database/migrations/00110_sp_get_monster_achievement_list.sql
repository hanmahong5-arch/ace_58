-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetMonsterAchievementList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetMonsterAchievementList.sql
-- Loads every (achieve_id → count, grade, reward_received) row for one char.
-- Called on character login to rehydrate the bestiary tab.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmonsterachievementlist(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getmonsterachievementlist(_char_id INTEGER)
RETURNS TABLE (
    out_char_id          INTEGER,
    out_achieve_id       INTEGER,
    out_achieved_count   INTEGER,
    out_achieved_grade   SMALLINT,
    out_reward_received  SMALLINT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT uma.char_id, uma.achieve_id, uma.achieved_count,
           uma.achieved_grade, uma.reward_received
      FROM user_monster_achievement uma
     WHERE uma.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getmonsterachievementlist(INTEGER);
-- +goose StatementEnd
