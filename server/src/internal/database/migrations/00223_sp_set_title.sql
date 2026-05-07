-- AionCore 5.8 — Sprint 1.1a batch 17 port: aion_SetTitle (active-title UPDATE on user_data).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetTitle.sql
-- Original (T-SQL):
--   UPDATE user_data
--   SET cur_title_id=@nCurTitleId,
--       change_info_time = dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)
--   WHERE char_id  =  @nCharId
--
-- Translation notes:
--   * Switches the *currently displayed* title for a char (the 5.8 client
--     calls this when the player picks a title from their owned set).
--   * Pure UPDATE on user_data PK(char_id). If the char does not exist,
--     0 rows affected — NCSoft @@ROWCOUNT = 0, no error. We mirror exactly.
--   * `change_info_time` is bumped using GetUnixtimeWithUTCAdjust(NOW(),0),
--     identical to the precedent set by 00006 SetCharDeleteTime / 00012
--     SetCharLoginTime / 00044 SetCharInfo. The PG helper is defined in
--     00002. The 0-hour offset matches NCSoft `dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)`.
--   * Parameter widths verified against NCSoft schema:
--       @nCharID      INT  → INTEGER (binds to user_data.char_id, PK)
--       @nCurTitleId  INT  → INTEGER (binds to user_data.cur_title_id,
--                                     added in 00032 round-3 scaffold)
--   * Returns rows-affected (1 on success / 0 if char missing).
--   * VOLATILE — data-modifying.
--
-- Bug-for-bug:
--   * No catalog FK on cur_title_id. NCSoft validates titles in gameplay
--     code, not at the column. Means a GM tool can pin cur_title_id to an
--     unreleased title id; pinned verbatim — do NOT add a CHECK.
--   * Title 0 is the canonical "no title equipped" sentinel. The SP
--     accepts 0 with no special-casing — pinned. Setting cur_title_id to
--     0 effectively clears the displayed title.
--   * Negative title ids are accepted by NCSoft (signed INT column);
--     observed in dev / test environments as flag values. Pinned.
--
-- Used by:
--   scripts/handlers/cm_title_select.lua  (player picks active title)
--   scripts/lib/title.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settitle(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_settitle(
    _char_id      INTEGER,
    _cur_title_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure UPDATE on user_data PK(char_id). Bumps change_info_time epoch
    -- so client cache invalidation triggers. 0 rows affected = char missing.
    UPDATE user_data
       SET cur_title_id     = _cur_title_id,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settitle(INTEGER, INTEGER);
-- +goose StatementEnd
