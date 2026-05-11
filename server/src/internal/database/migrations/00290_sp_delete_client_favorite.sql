-- AionCore 5.8 — batch 29 / 5 of 5: aion_DeleteClientfavorite — wipe favorites list.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteClientfavorite.sql
-- Original (T-SQL):
--   CREATE procedure [dbo].[aion_DeleteClientfavorite]
--       @nCharId int
--   as
--   SET NOCOUNT ON
--   DELETE FROM user_client_favorite WHERE char_id=@nCharId
--   set nocount off
--
-- Translation notes:
--   * user_client_favorite created at 00161. Schema is `(char_id PK,
--     data_size, data BYTEA)` — one opaque blob row per char holding the
--     full favorites list. This SP wipes that row — invoked on char-delete
--     cascade.
--   * NCSoft mixes case: SP is `Clientfavorite` (lower f) but PG SP is
--     `clientfavorite` (PG identifier folds to lower regardless). Sibling
--     SPs use upper-camel (ClientSettings, ClientQuickBar) — naming
--     drift in the dump; pinned.
--   * Returns INTEGER rows-affected (0 or 1; widening of NCSoft VOID).
--
-- Bug-for-bug:
--   * Empty char → 0, silent. Pinned.
--   * Idempotent.
--
-- Used by:
--   scripts/lib/char_purge.lua  -- delete-cascade helper

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteclientfavorite(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteclientfavorite(
    _char_id INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    n INTEGER;
BEGIN
    DELETE FROM user_client_favorite WHERE char_id = _char_id;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteclientfavorite(INTEGER);
-- +goose StatementEnd
