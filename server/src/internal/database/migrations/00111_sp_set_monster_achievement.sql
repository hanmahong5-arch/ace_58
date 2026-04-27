-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetMonsterAchievement.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetMonsterAchievement.sql
-- T-SQL pattern: UPDATE first; if @@ROWCOUNT = 0 then INSERT.
-- PG idiom: INSERT ... ON CONFLICT DO UPDATE.
--
-- Important: reward_received is preserved across UPDATE because the
-- UPDATE-then-INSERT pattern only touches count+grade. We replicate this
-- exactly via "DO UPDATE SET (count, grade) = ..." so reward_received stays
-- monotonic regardless of how often this SP is called.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmonsterachievement(INTEGER, INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmonsterachievement(
    _char_id         INTEGER,
    _achieve_id      INTEGER,
    _achieved_count  INTEGER,
    _achieved_grade  SMALLINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_monster_achievement
        (char_id, achieve_id, achieved_count, achieved_grade, reward_received)
    VALUES
        (_char_id, _achieve_id, _achieved_count, _achieved_grade, 0)
    ON CONFLICT (char_id, achieve_id) DO UPDATE
       SET achieved_count = EXCLUDED.achieved_count,
           achieved_grade = EXCLUDED.achieved_grade;
    -- reward_received intentionally NOT in the SET list — UPDATE branch must
    -- not touch it (matches T-SQL: UPDATE only sets count+grade).
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmonsterachievement(INTEGER, INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd
