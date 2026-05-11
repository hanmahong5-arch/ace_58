-- AionCore 5.8 — batch 29 / 3 of 5: aion_DeleteClientSettings — wipe per-char UI prefs.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteClientSettings.sql
-- Original (T-SQL):
--   create procedure [dbo].[aion_DeleteClientSettings]
--       @nCharId int
--   as
--   SET NOCOUNT ON
--   DELETE FROM user_client_settings WHERE char_id=@nCharId
--   set nocount off
--
-- Translation notes:
--   * user_client_settings was created at 00154/00155 (client_settings get/put).
--     Schema is `(char_id PK, data_size, data BYTEA)` — one row per char that
--     holds an opaque blob of UI prefs. This SP wipes that single row.
--     NCSoft uses it on character-delete cascade and on the
--     "reset UI to defaults" GM command.
--   * Returns INTEGER rows-affected (0 or 1, since char_id is PK). Strict
--     widening of NCSoft VOID, batch-27/28 convention.
--
-- Bug-for-bug:
--   * Empty char → 0, silent. Pinned.
--   * Idempotent.
--
-- Used by:
--   scripts/lib/char_purge.lua            -- delete-cascade helper
--   scripts/admin/gm_reset_client_settings.lua  -- GM UI-defaults reset

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteclientsettings(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteclientsettings(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    n INTEGER;
BEGIN
    DELETE FROM user_client_settings WHERE char_id = _char_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteclientsettings(INTEGER);
-- +goose StatementEnd
