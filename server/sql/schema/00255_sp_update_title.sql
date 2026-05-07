-- AionCore 5.8 — Sprint 1.1a batch 24 port: aion_UpdateTitle
-- (UPSERT on user_title — write-side complement of 00162 GetTitle).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_UpdateTitle.sql
-- Original (T-SQL):
--   if EXISTS (SELECT char_id FROM user_title(updlock)
--              WHERE char_id = @nCharId and title_id=@nTitleId)
--     UPDATE user_title SET is_have=@bHave, expired_time=@nExpired
--      WHERE char_id=@nCharId and title_id=@nTitleId
--   else
--     INSERT user_title(char_id, title_id, is_have, expired_time)
--     VALUES (@nCharId, @nTitleId, @bHave, @nExpired)
--
-- Domain (`char_title`, sister to 00162/00223/00254):
--   user_title is the per-character ledger of every title ever awarded.
--   This SP is invoked when a quest / event / GM grant adds a new title or
--   updates an existing one (e.g. extending the expiry of a time-limited
--   "founder" title). It must be re-entrant for both new awards and
--   refresh-existing.
--
-- Translation notes:
--   * NCSoft `IF EXISTS … UPDATE … ELSE INSERT` race-prone idiom collapsed
--     to PostgreSQL `INSERT ... ON CONFLICT DO UPDATE`. The conflict target
--     matches user_title's composite PK (char_id, title_id) defined in 00162.
--   * The original UPDLOCK hint is satisfied by the row-level lock acquired
--     during ON CONFLICT DO UPDATE — equivalent atomicity guarantee.
--   * Parameter widths verified against NCSoft schema:
--       @nCharId   INT     → INTEGER  (user_title.char_id  composite PK)
--       @nTitleId  INT     → INTEGER  (user_title.title_id composite PK)
--       @bHave     CHAR(1) → BOOLEAN  (NCSoft stores 0/1 in CHAR; PG uses
--                                      native BOOLEAN — see 00162 header)
--       @nExpired  INT     → BIGINT   (00162 widened expired_time to BIGINT
--                                      for unix-epoch headroom; we accept
--                                      INT input to mirror NCSoft signature
--                                      and let PG implicit-widen on assign)
--   * Returns rows-affected: always 1 on success (whether INSERT or UPDATE
--     branch), 0 only when the conflict-target collision raises (impossible
--     for a well-formed call — surfaced for diagnostic symmetry).
--   * VOLATILE — data-modifying.
--
-- Bug-for-bug:
--   * NCSoft signs `is_have` as CHAR(1) but the application writes ASCII '0'/'1'
--     — pinned at the application layer (handler converts before calling SP).
--   * No FK on title_id (NCSoft validates in gameplay code). A GM tool may
--     write an unreleased title; pinned verbatim — do NOT add a CHECK.
--   * No is_have-uniqueness constraint at the SP layer. NCSoft expects
--     the caller to demote the prior is_have=true row before promoting a
--     new one; this SP does NOT enforce that. Pinned.
--
-- Used by:
--   scripts/lib/title.lua
--   scripts/quests/title_award.lua  (quest-driven title grant)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatetitle(INTEGER, INTEGER, BOOLEAN, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updatetitle(
    _char_id      INTEGER,
    _title_id     INTEGER,
    _is_have      BOOLEAN,
    _expired_time INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- UPSERT on user_title (char_id, title_id) composite PK from 00162.
    -- Replaces NCSoft's IF EXISTS … UPDATE … ELSE INSERT pattern atomically.
    INSERT INTO user_title (char_id, title_id, is_have, expired_time)
    VALUES (_char_id, _title_id, _is_have, _expired_time)
    ON CONFLICT (char_id, title_id) DO UPDATE
        SET is_have      = EXCLUDED.is_have,
            expired_time = EXCLUDED.expired_time;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updatetitle(INTEGER, INTEGER, BOOLEAN, INTEGER);
-- +goose StatementEnd
