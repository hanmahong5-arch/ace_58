-- AionCore 5.8 — Sprint 1.1a batch 14 port: aion_ChangeEnhancedStigmaSlotCnt (stigma slot count change).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ChangeEnhancedStigmaSlotCnt.sql
-- Original (T-SQL):
--   IF NOT EXISTS (SELECT char_id FROM user_data
--                   WHERE char_id=@nCharID
--                     AND (delete_date = 0 OR (delete_date >
--                          dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0))))
--       return -1
--   UPDATE user_data
--      SET enhanced_stigma_slot_cnt = @cnt
--    WHERE char_id = @nCharId
--   IF @@ERROR <> 0
--       return 0
--   return @nCharID
--
-- Translation notes:
--   * Three return paths preserved bug-for-bug:
--       -1  = char not found OR is in past-grace deletion window
--        0  = update raised an error (PG: caught by EXCEPTION)
--       @nCharID  = success; returns the input char_id
--   * Returning the char_id on success is NCSoft's "echo on success" idiom;
--     callers compare `rc == @nCharID` to confirm. Pinned for compat.
--   * `delete_date = 0` means "alive forever"; otherwise it's a Unix-epoch
--     deletion deadline. The comparison with GetUnixtimeWithUTCAdjust is
--     "deletion is in the future" → still recoverable → still mutable.
--   * `enhanced_stigma_slot_cnt` column already lives in user_data (added
--     by migration 00032 pve_scaffold_round3 line 176). No ALTER needed.
--   * `cnt` parameter is TINYINT (0..255) in T-SQL; PG SMALLINT covers it.
--     Caller passes a single byte — current 5.8 caps at 6 enhanced slots.
--
-- Bug-for-bug:
--   * The "delete_date in the future" guard ALSO blocks updates on a freshly
--     scheduled-for-deletion char during the grace window — even though the
--     char data is still on disk. Pinned (matches T-SQL's strictness).
--   * No FK guard on cnt range; passing 999 stores 999. NCSoft accepts it.
--
-- Used by:
--   scripts/handlers/cm_stigma_slot_grant.lua  (Q1 — enhanced stigma rollout)
--   scripts/lib/stigma.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changeenhancedstigmaslotcnt(INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_changeenhancedstigmaslotcnt(
    _char_id  INTEGER,
    _cnt      SMALLINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    exists_alive BOOLEAN;
BEGIN
    -- Existence + grace-window guard. delete_date=0 means alive; or the
    -- deletion deadline must be in the future (epoch seconds, UTC).
    SELECT EXISTS (
        SELECT 1 FROM user_data
         WHERE char_id = _char_id
           AND (delete_date = 0
                OR delete_date > GetUnixtimeWithUTCAdjust(NOW(), 0))
    ) INTO exists_alive;

    IF NOT exists_alive THEN
        RETURN -1;
    END IF;

    BEGIN
        UPDATE user_data
           SET enhanced_stigma_slot_cnt = _cnt
         WHERE char_id = _char_id;
    EXCEPTION WHEN OTHERS THEN
        -- Mirrors T-SQL `IF @@ERROR <> 0 return 0`. Any update failure
        -- surfaces as 0 (NOT -1, which is reserved for "not found").
        RETURN 0;
    END;

    -- "Echo on success" idiom: returning the char_id confirms the row hit.
    RETURN _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_changeenhancedstigmaslotcnt(INTEGER, SMALLINT);
-- +goose StatementEnd
