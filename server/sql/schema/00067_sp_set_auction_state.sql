-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port: aion_setauctionstate.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_setauctionstate.sql
--
-- Update the state field of an auction row.
--   0 → in-progress, 1 → ready-to-settle, 2..N → settled / cancelled.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctionstate(BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setauctionstate(
    _id    BIGINT,
    _state INTEGER
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_auction AS ua
       SET state = _state::SMALLINT
     WHERE ua.id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctionstate(BIGINT, INTEGER);
-- +goose StatementEnd
