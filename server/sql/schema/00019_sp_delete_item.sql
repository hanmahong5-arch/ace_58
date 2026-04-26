-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_DeleteItem.
--
-- Resolves Round 4 MISSING entry — turns out aion_DeleteItem DOES exist in
-- the NCSoft dump (Round 4 audit missed it). (decision logged in priority-50.md)
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteItem.sql
-- Cascading DELETE across user_item + 4 sister tables. Our scaffold uses
-- ON DELETE CASCADE FK on user_item_option/_charge/_polish/_attribute, so
-- a single DELETE FROM user_item is functionally equivalent. We keep the
-- explicit per-table deletes as safety nets (and to mirror T-SQL semantics
-- for any future case where FK is dropped).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitem(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitem(_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM user_item_attribute WHERE id = _id;
    DELETE FROM user_item_polish    WHERE id = _id;
    DELETE FROM user_item_charge    WHERE id = _id;
    DELETE FROM user_item_option    WHERE id = _id;
    DELETE FROM user_item           WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitem(BIGINT);
-- +goose StatementEnd
