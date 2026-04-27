-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteFamiliar.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteFamiliar.sql
--
-- Soft-delete (deleted=1 + bumped update_time). The actual GC of
-- deleted=1 rows is handled by an external scheduled task — preserving
-- the soft-delete window lets admins restore a familiar that was removed
-- by mistake, identical to the user_item.warehouse=10 trash bucket.
--
-- T-SQL body:
--   UPDATE user_familiar
--   SET update_time = @updateTime, deleted = 1
--   WHERE id = @dbId AND char_id = @masterId
--
-- Translation note: T-SQL @dbId / @updateTime are bigint. In PG we keep
-- them BIGINT (the user_familiar.id is BIGSERIAL → BIGINT). This SP
-- requires both id AND char_id to match — one familiar can only be
-- removed by its owning master, even if the dbId is known to a third
-- party (gift / trade fraud-prevention).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefamiliar(BIGINT, INTEGER, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deletefamiliar(
    _db_id       BIGINT,
    _master_id   INTEGER,
    _update_time BIGINT
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_familiar
       SET update_time = _update_time,
           deleted     = 1
     WHERE id      = _db_id
       AND char_id = _master_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletefamiliar(BIGINT, INTEGER, BIGINT);
-- +goose StatementEnd
