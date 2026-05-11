-- AionCore 5.8 — batch 29 / 4 of 5: aion_DeleteClientQuickBar — wipe hotkey bar.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteClientQuickBar.sql
-- Original (T-SQL):
--   CREATE procedure [dbo].[aion_DeleteClientQuickBar]
--       @char_id int
--   as
--   SET NOCOUNT ON
--   DELETE FROM user_client_quickbar WHERE char_id = @char_id
--   set nocount off
--
-- Translation notes:
--   * user_client_quickbar created at 00160. Schema is `(char_id PK,
--     data_size, data BYTEA)` — one opaque blob row per char holding all
--     hotkey slots. This SP wipes that row — invoked on char-delete and
--     on "Reset Hotkey Bar" GM op.
--   * Returns INTEGER rows-affected (0 or 1; widening of NCSoft VOID).
--
-- Bug-for-bug:
--   * Empty char → 0, silent. Pinned.
--   * Idempotent.
--
-- Used by:
--   scripts/lib/char_purge.lua           -- delete-cascade helper
--   scripts/admin/gm_reset_quickbar.lua  -- GM hotkey-reset

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteclientquickbar(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteclientquickbar(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    n INTEGER;
BEGIN
    DELETE FROM user_client_quickbar WHERE char_id = _char_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteclientquickbar(INTEGER);
-- +goose StatementEnd
