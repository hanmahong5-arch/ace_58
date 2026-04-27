-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetUserInstance.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetUserInstance.sql
-- Older sibling of GetUserInstance_20171122 (00025) — returns 6 columns only
-- (no kina/item/spinel increase columns). Kept for client-binary back-compat.
-- LEFT JOIN instance to surface validity_time which lives on the design-time
-- instance row, not the per-char user_instance row.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserinstance(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserinstance(_char_id INTEGER)
RETURNS TABLE (
    out_server_id        INTEGER,
    out_world_id         INTEGER,
    out_instance_id      INTEGER,
    out_reentrance_time  INTEGER,
    out_count_variate    INTEGER,
    out_validity_time    INTEGER
)
LANGUAGE plpgsql AS $$
-- OUT cols prefixed `out_` to avoid PG's "field reference is ambiguous"
-- when the body references identically-named user_instance columns.
BEGIN
    RETURN QUERY
    SELECT ui.server_id, ui.world_id, ui.instance_id,
           ui.reentrance_time, ui.count_variate,
           COALESCE(i.validity_time, 0)
      FROM user_instance ui
      LEFT JOIN instance i ON ui.instance_id = i.instance_id
     WHERE ui.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserinstance(INTEGER);
-- +goose StatementEnd
