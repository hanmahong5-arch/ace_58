-- AionCore 5.8 — Sprint 1.1a Round 9 (Track B7) port: aion_GetInstanceExtraCountAbyssOP.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetInstanceExtraCountAbyssOP.sql
-- Returns rows whose next_reset_time has not yet been crossed. The caller
-- passes the cluster-wide @opResetTime so we filter inclusively (>=).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstanceextracountabyssop(INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getinstanceextracountabyssop(
    _char_id       INTEGER,
    _op_reset_time BIGINT
)
RETURNS TABLE (
    out_map_number          INTEGER,
    out_extra_count_abyssop SMALLINT,
    out_next_reset_time     BIGINT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT uie.map_number, uie.extra_count_abyssop, uie.next_reset_time
      FROM user_instance_extracount uie
     WHERE uie.char_id = _char_id
       AND uie.next_reset_time >= _op_reset_time;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getinstanceextracountabyssop(INTEGER, BIGINT);
-- +goose StatementEnd
