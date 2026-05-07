-- AionCore 5.8 — Sprint 1.1a batch 9 port: aion_ClearPetitionMsg (NULL-out / DELETE petition msg).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_ClearPetitionMsg.sql
-- Original (T-SQL):
--   IF @nPetSvId = @nLocalSv
--       UPDATE user_data SET petition_msg = NULL WHERE char_id = @nCharId
--   ELSE
--       DELETE FROM user_petition_msg WHERE char_id = @nCharId AND petition_sv_id = @nPetSvId
--
-- Translation notes:
--   * Mirror of 00179 SetPetitionMsg branch logic, but with NULL/DELETE
--     instead of write payload:
--       - Same-shard  → UPDATE user_data SET petition_msg = NULL.
--       - Cross-shard → DELETE the queued (char_id, petition_sv_id) row.
--   * NULL on same-shard (rather than empty string) is the canonical
--     "no live petition" sentinel — 00178 GetPetitionMsg coalesces NULL
--     to '' on the read path so the wire payload is never NULL but the
--     storage layer keeps the explicit NULL.
--   * The original T-SQL keeps a commented-out IF EXISTS guard before
--     DELETE; we drop it in PG since DELETE on no-match is a 0-row no-op
--     (the IF EXISTS was a SQL Server-ism for UPDLOCK ordering, not
--     needed in PG's MVCC model).
--   * Returns rows-affected so the caller can detect "msg actually
--     cleared" (1) vs "nothing to clear" (0). 5.8 client uses this to
--     tell the player "petition closed" vs ignore the request.
--
-- Used by:
--   scripts/handlers/cm_petition_msg_clear.lua  -- player closes petition
--   scripts/lib/petition.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearpetitionmsg(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clearpetitionmsg(
    _char_id   INTEGER,
    _pet_sv_id INTEGER,
    _local_sv  INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    IF _pet_sv_id = _local_sv THEN
        -- Same-shard: NULL out the live msg on user_data.
        UPDATE user_data
           SET petition_msg = NULL
         WHERE char_id = _char_id;
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    ELSE
        -- Cross-shard: drop the queued row outright.
        DELETE FROM user_petition_msg
         WHERE char_id = _char_id
           AND petition_sv_id = _pet_sv_id;
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    END IF;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clearpetitionmsg(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
