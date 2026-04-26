-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_GetUserInstance_20171122.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetUserInstance_20171122.sql
-- Side effect: deletes the world_id=302350000 row before SELECT (lobby that
-- always resets per session). Then joins user_instance LEFT instance to
-- include the design-time validity_time.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserinstance_20171122(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserinstance_20171122(_char_id INTEGER)
RETURNS TABLE (
    out_server_id        INTEGER,
    out_world_id         INTEGER,
    out_instance_id      INTEGER,
    out_reentrance_time  INTEGER,
    out_count_variate    INTEGER,
    out_validity_time    INTEGER,
    out_kina_increase    INTEGER,
    out_item_increase    INTEGER,
    out_spinel_increase  INTEGER
)
LANGUAGE plpgsql AS $$
-- OUT-param names are prefixed with `out_` so they cannot shadow real
-- table column names inside the body (PL/pgSQL otherwise raises
-- "field reference X is ambiguous"). Caller-side scan still positional.
BEGIN
    DELETE FROM user_instance ui
     WHERE ui.char_id = _char_id AND ui.world_id = 302350000;

    RETURN QUERY
    SELECT ui.server_id, ui.world_id, ui.instance_id,
           ui.reentrance_time, ui.count_variate,
           COALESCE(i.validity_time, 0),
           ui.kina_increase, ui.item_increase, ui.spinel_increase
      FROM user_instance ui
      LEFT JOIN instance i ON ui.instance_id = i.instance_id
     WHERE ui.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserinstance_20171122(INTEGER);
-- +goose StatementEnd
