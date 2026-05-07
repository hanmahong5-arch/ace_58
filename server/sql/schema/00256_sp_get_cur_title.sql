-- AionCore 5.8 — Sprint 1.1a batch 24 port: aion_GetCurTitle_20120417
-- (login-time hydration of cur_title_id + cur_title_attr_id from user_data).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetCurTitle_20120417.sql
-- Original (T-SQL):
--   SELECT cur_title_id, cur_title_attr_id FROM user_data WHERE char_id=@nUserId
--
-- Domain (`char_title`, sister to 00162/00223/00254/00255):
--   The login flow needs both title selectors before sending SM_PLAYER_INFO,
--   because the client renders the displayed title (cur_title_id) and applies
--   the stat bonus (cur_title_attr_id) at character spawn time. NCSoft kept
--   the read narrow (just the two columns) rather than relying on the giant
--   00043 GetCharInfo_20160818 SELECT — fewer bytes on the wire when only
--   the title pair is being refreshed (e.g. after a 00223/00254 write).
--
-- Translation notes:
--   * Renamed _20120417 suffix dropped on the PG side: AION 5.8 has no
--     other GetCurTitle variant, and the suffix is just NCSoft's internal
--     versioning marker. The Go caller will reference `aion_getcurtitle`.
--   * Single-row result: zero rows when the char does not exist (the caller
--     interprets that as "no character" — matches NCSoft empty-set behaviour).
--   * Function declared STABLE — no side effects, deterministic per snapshot.
--   * Parameter widths verified against NCSoft schema:
--       @nUserId INT → INTEGER (PK on user_data.char_id; despite the name
--                               this is char_id, not account_id — pinned).
--   * Column types in the RETURNS TABLE clause mirror the user_data columns
--     added by 00032 (cur_title_id INT, cur_title_attr_id INT — both
--     defaults to 0 for a newly-created char with no titles).
--
-- Bug-for-bug:
--   * Misnamed parameter @nUserId actually carries char_id, not account_id —
--     NCSoft historical artefact from an early schema where char_id was
--     misnamed user_id. Pinned in the SP body but parameter renamed to
--     `_char_id` on the PG side for caller clarity (the wire signature is
--     positional so renaming is harmless).
--
-- Used by:
--   scripts/handlers/cm_enter_world.lua  (title pair hydration on login)
--   scripts/lib/title.lua                (after a SetTitle / SetAttrTitle write)

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcurtitle(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcurtitle(_char_id INTEGER)
RETURNS TABLE (
    cur_title_id      INTEGER,
    cur_title_attr_id INTEGER
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ud.cur_title_id, ud.cur_title_attr_id
          FROM user_data ud
         WHERE ud.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcurtitle(INTEGER);
-- +goose StatementEnd
