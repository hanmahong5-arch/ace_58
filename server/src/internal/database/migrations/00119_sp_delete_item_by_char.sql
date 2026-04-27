-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_DeleteItemByChar.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteItemByChar.sql
--
-- T-SQL body (verbatim):
--   /*** DELETE user_item WHERE char_id = @nCharId AND warehouse = @nWarehouse ***/
--   Update user_item
--   Set warehouse=10, update_date=GETDATE()
--   WHERE char_id = @nCharId AND warehouse = @nWarehouse
--
-- The commented-out DELETE is preserved in NCSoft's source as historical
-- record: at some point an admin changed hard-delete to soft-archive into
-- warehouse 10 (the "trash" / forensic bucket). Items remain physically in
-- user_item indefinitely; an offline GC compacts warehouse=10 rows older
-- than ~30 days.
--
-- Translation note: NCSoft's @nWarehouse semantics — caller passes the
-- ORIGINAL warehouse number (0=inventory, 1=acc-warehouse, 2=char-warehouse,
-- etc.) and the SP relocates rows in THAT bucket to bucket 10. The cascade
-- caller invokes this SP once per warehouse the character owns.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitembychar(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitembychar(
    _char_id   INTEGER,
    _warehouse INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_item
       SET warehouse   = 10,
           update_date = NOW()
     WHERE char_id   = _char_id
       AND warehouse = _warehouse;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitembychar(INTEGER, INTEGER);
-- +goose StatementEnd
