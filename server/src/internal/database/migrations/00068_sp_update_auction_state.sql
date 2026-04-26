-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port: aion_updateauctionstate.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_updateauctionstate.sql
--
-- Apply a new highest bid: update price, lastupdate timestamp, buyer info,
-- and increment the bet counter atomically.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updateauctionstate(BIGINT, BIGINT, INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updateauctionstate(
    _id          BIGINT,
    _qina        BIGINT,
    _lastupdate  INTEGER,
    _buyer       INTEGER,
    _buyername   TEXT
)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_auction AS ua
       SET qina       = _qina,
           lastupdate = _lastupdate,
           buyerid    = _buyer,
           buyername  = _buyername,
           betcount   = ua.betcount + 1
     WHERE ua.id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updateauctionstate(BIGINT, BIGINT, INTEGER, INTEGER, TEXT);
-- +goose StatementEnd
