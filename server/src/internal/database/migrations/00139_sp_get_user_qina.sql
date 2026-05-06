-- AionCore 5.8 — Sprint 1.1a batch 1 port: aion_GetUserQina (kinah/金币 lookup).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetUserQina.sql
-- Original (T-SQL):
--   select top 1 id, amount from user_item (nolock)
--    where char_id = @charid and name_id = 182400001 and warehouse = 0
--
-- 182400001 is the hard-coded NCSoft kinah item template_id; warehouse=0 means
-- the row lives in the player's bag (warehouse buckets >0 hide kinah from the
-- in-bag stack). Returning (id, amount) so the caller can either issue a
-- delta-update by id (cheaper than re-querying) or just read the balance.
--
-- LIMIT 1 mirrors NCSoft's `top 1`: under healthy invariants there is exactly
-- one bag-kinah row per char, but a corrupted state (duplicate inserts) must
-- never raise — return the first row deterministically by id (lowest = oldest).
-- Returns 0 rows for chars who somehow have no kinah row (fresh-create before
-- starter kit runs, hand-cleaned DB rows); callers default to amount=0.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserqina(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserqina(_char_id INTEGER)
RETURNS TABLE (
    id     BIGINT,
    amount BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT ui.id, ui.amount
          FROM user_item ui
         WHERE ui.char_id   = _char_id
           AND ui.name_id   = 182400001
           AND ui.warehouse = 0
         ORDER BY ui.id ASC
         LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserqina(INTEGER);
-- +goose StatementEnd
