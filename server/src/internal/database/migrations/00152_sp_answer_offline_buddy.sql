-- AionCore 5.8 — Sprint 1.1a batch 3 port: aion_AnswerOfflineBuddy.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AnswerOfflineBuddy.sql
--
-- Original (T-SQL) — paraphrased:
--   if (charId, inviterId) already on charId's active list             → return 2  (already friends)
--   if inviter doesn't exist OR is the wrong race vs invitee           → return 3  (not exist)
--   if invitee's active buddy_list count >= 200                        → return 5  (invitee full)
--   if inviter's active buddy_list count >= 200                        → return 5  (inviter full)
--   else INSERT user_buddy1(inviter, charId, 0) and read inviter's
--        (lev, class, gender, world, daily_comment) as OUTPUT params   → return 0
--
-- Schema delta:
--   None. user_data already carries race / class / gender (BOOLEAN) /
--   daily_comment via the 00032 PvE round-3 widening. We just need to cast
--   gender to INTEGER on the OUT column so the C# / Lua callers (which expect
--   the legacy NCSoft int representation) can keep their existing decoders.
--
-- Translation notes:
--   * NCSoft used 5 OUTPUT parameters + an integer RETURN. PG plpgsql's
--     equivalent is a single RETURNS TABLE row whose first column is the
--     return code; the caller does CallSPRow(...).Scan(&rc, &lev, &class, ...).
--     This collapses 6 round-trips into 1 and keeps the call site readable.
--   * NCSoft used `(nolock)` hints on user_buddy1 + user_data — dropped, see
--     reasoning in 00151. PG MVCC makes the read non-blocking and snapshot-
--     consistent (which is what NCSoft was actually after, dirty-reads aside).
--   * Race-match check: `inviter.race = invitee.race`. AION forbids
--     cross-faction friendships at the SP layer; the client UI also enforces
--     it but the server is the authoritative gate.
--   * The 200 cap here ≠ the 100 cap in aion_AddOfflineBuddy — see notes there.
--   * On-success side-effect: ONLY the inviter→invitee row is inserted. The
--     reverse direction (invitee→inviter) is the responsibility of the caller
--     (typically aion_AddBuddy invoked back-to-back) so we don't double-fire
--     SM_FRIEND_LIST events here.

-- +goose Up

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_answer_offline_buddy(INTEGER, TEXT, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_answer_offline_buddy(
    _char_id       INTEGER,
    _char_name     TEXT,
    _inviter_id    INTEGER,
    _inviter_name  TEXT
)
RETURNS TABLE (
    out_result        INTEGER,
    out_level         INTEGER,
    out_class         INTEGER,
    out_gender        INTEGER,
    out_world         INTEGER,
    out_today_word    TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    invitee_race SMALLINT;
    inviter_race SMALLINT;
    buddy_count  INTEGER;
BEGIN
    -- Defaults that match the NCSoft `set @x = 0` zero-init block.
    out_result     := 0;
    out_level      := 0;
    out_class      := 0;
    out_gender     := 0;
    out_world      := 0;
    out_today_word := '';

    -- (1) Already friends?
    IF EXISTS (SELECT 1 FROM user_buddy_list
                WHERE char_id = _char_id AND buddy_id = _inviter_id) THEN
        out_result := 2;
        RETURN NEXT;
        RETURN;
    END IF;

    -- (2) Inviter must exist AND share the invitee's race.
    SELECT race INTO invitee_race FROM user_data WHERE char_id = _char_id     LIMIT 1;
    SELECT race INTO inviter_race FROM user_data WHERE char_id = _inviter_id  LIMIT 1;
    IF inviter_race IS NULL OR invitee_race IS NULL OR inviter_race <> invitee_race THEN
        out_result := 3;
        RETURN NEXT;
        RETURN;
    END IF;

    -- (3) Invitee active-buddy ceiling (200).
    SELECT COUNT(*) INTO buddy_count FROM user_buddy_list WHERE char_id = _char_id;
    IF buddy_count >= 200 THEN
        out_result := 5;
        RETURN NEXT;
        RETURN;
    END IF;

    -- (4) Inviter active-buddy ceiling (200).
    SELECT COUNT(*) INTO buddy_count FROM user_buddy_list WHERE char_id = _inviter_id;
    IF buddy_count >= 200 THEN
        out_result := 5;
        RETURN NEXT;
        RETURN;
    END IF;

    -- (5) Insert inviter→invitee row (the invitee is offline-becoming-online,
    --     so we add the row from the inviter's perspective). delete_flag=0
    --     marks it active. The reverse direction is the caller's job.
    INSERT INTO user_buddy_list (char_id, buddy_id, delete_flag)
    VALUES (_inviter_id, _char_id, 0)
    ON CONFLICT (char_id, buddy_id) DO NOTHING;

    -- (6) Hydrate the SM_BUDDY_RESPONSE payload from the inviter's user_data.
    --     gender is BOOLEAN in user_data (00032); cast to INTEGER (0/1) so
    --     the wire payload keeps the legacy NCSoft byte semantics.
    SELECT COALESCE(lev, 0),
           COALESCE(class, 0)::INTEGER,
           CASE WHEN COALESCE(gender, FALSE) THEN 1 ELSE 0 END,
           COALESCE(world, 0),
           COALESCE(daily_comment, '')
      INTO out_level, out_class, out_gender, out_world, out_today_word
      FROM user_data
     WHERE char_id = _inviter_id
     LIMIT 1;

    out_result := 0;
    RETURN NEXT;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_answer_offline_buddy(INTEGER, TEXT, INTEGER, TEXT);
-- +goose StatementEnd
