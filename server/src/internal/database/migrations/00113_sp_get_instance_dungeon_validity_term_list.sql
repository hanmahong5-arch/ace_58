-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetInstanceDungeonValidityTermList.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetInstanceDungeonValidityTermList.sql
--
-- The original NCSoft body is empty — only `SET NOCOUNT ON;`. NCSoft kept
-- the SP signature to satisfy boot-time client lookups but moved the actual
-- payload elsewhere (likely into the static dungeon-config XML in 5.x).
-- We mirror the empty contract: returns zero rows, never errors.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstancedungeonvaliditytermlist();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstancedungeonvaliditytermlist()
RETURNS TABLE (
    out_dummy INTEGER  -- shape placeholder; never produces a row.
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Empty body verbatim from T-SQL.
    RETURN;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstancedungeonvaliditytermlist();
-- +goose StatementEnd
