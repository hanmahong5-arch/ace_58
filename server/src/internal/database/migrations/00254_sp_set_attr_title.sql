-- AionCore 5.8 — Sprint 1.1a batch 24 port: aion_SetAttrTitle
-- (active-attribute-title UPDATE on user_data — sister of 00223 SetTitle).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetAttrTitle.sql
-- Original (T-SQL):
--   UPDATE user_data
--   SET cur_title_attr_id=@nCurAttrTitleId,
--       change_info_time = dbo.GetUnixtimeWithUTCAdjust(GetUTCDate(),0)
--   WHERE char_id  =  @nCharId
--
-- Domain (`char_title`, sister to 00162/00223):
--   AION 5.8 splits a character's "displayed title" into two columns:
--     * cur_title_id      — selected title row (00223 setter)
--     * cur_title_attr_id — selected attribute-grant title row (this SP)
--   Both can be 0 ("none equipped"). The client renders the title text from
--   cur_title_id and applies the stat bonus from cur_title_attr_id; they are
--   intentionally orthogonal so a player can wear a fancy display title while
--   running a different stat-buff title underneath.
--
-- Translation notes:
--   * Pure UPDATE on user_data PK(char_id). 0 rows affected when the char
--     does not exist — pinned (NCSoft @@ROWCOUNT = 0, no error).
--   * `change_info_time` bumped via GetUnixtimeWithUTCAdjust(NOW(),0) to
--     mirror 00223 SetTitle and 00044 SetCharInfo cache-invalidation
--     contract (the gateway watches this column to know when to push a
--     fresh user_data snapshot down to the client).
--   * Parameter widths verified against NCSoft schema:
--       @nCharID         INT → INTEGER (PK on user_data.char_id)
--       @nCurAttrTitleId INT → INTEGER (user_data.cur_title_attr_id, added 00032)
--   * Returns rows-affected (1 success / 0 if char missing).
--   * VOLATILE — data-modifying.
--
-- Bug-for-bug:
--   * No catalog FK on cur_title_attr_id. NCSoft validates legality in
--     gameplay code, not at the column. A GM tool can pin an unreleased
--     attr-title id; pinned verbatim — do NOT add a CHECK.
--   * Title attr 0 is the canonical "no attribute title" sentinel; the SP
--     accepts 0 with no special-casing.
--   * Negative ids are accepted (signed INT column). Pinned.
--
-- Used by:
--   scripts/handlers/cm_title_select.lua  (player picks active attribute title)
--   scripts/lib/title.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setattrtitle(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setattrtitle(
    _char_id           INTEGER,
    _cur_attr_title_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    -- Pure UPDATE on user_data PK(char_id). Bumps change_info_time epoch
    -- so the gateway picks up the field change on the next push.
    UPDATE user_data
       SET cur_title_attr_id = _cur_attr_title_id,
           change_info_time  = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id;
    GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setattrtitle(INTEGER, INTEGER);
-- +goose StatementEnd
