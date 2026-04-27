-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_SetMonsterAchievementRewardReceived.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetMonsterAchievementRewardReceived.sql
--
-- Atomic "claim grade N reward" handshake.
-- T-SQL signature (output, then char/achieve/level args):
--   @outGradeOfReward int output, @char_id, @achieve_id, @reward_received tinyint
--   UPDATE user_monster_achievement
--      SET reward_received = @reward_received,
--          @outGradeOfReward = @reward_received
--    WHERE char_id = @char_id
--      AND achieve_id = @achieve_id
--      AND reward_received = @reward_received - 1   -- ← sequential gate
--   RETURN @@ROWCOUNT
--
-- Key invariant: client cannot claim grade N before grade N-1 was claimed.
-- The WHERE clause enforces this atomically; the SP returns 1 on success
-- (and out_grade_of_reward = N) or 0 on failure (and out_grade_of_reward = -1).
--
-- PG implementation: RETURN both values via OUT params + INTEGER status.
-- Note rowcount-style return: PG plpgsql function returns rc only; out_grade
-- is exposed via RETURNS (..., OUT ...).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmonsterachievementrewardreceived(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setmonsterachievementrewardreceived(
    _char_id          INTEGER,
    _achieve_id       INTEGER,
    _reward_received  SMALLINT,
    OUT out_grade_of_reward INTEGER,
    OUT out_rowcount        INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    out_grade_of_reward := -1;
    out_rowcount        := 0;

    UPDATE user_monster_achievement
       SET reward_received = _reward_received
     WHERE char_id    = _char_id
       AND achieve_id = _achieve_id
       AND reward_received = _reward_received - 1;

    GET DIAGNOSTICS out_rowcount = ROW_COUNT;
    IF out_rowcount > 0 THEN
        out_grade_of_reward := _reward_received;
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setmonsterachievementrewardreceived(INTEGER, INTEGER, SMALLINT);
-- +goose StatementEnd
