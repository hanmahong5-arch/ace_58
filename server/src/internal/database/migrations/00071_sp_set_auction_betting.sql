-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port: aion_setAuctionBetting.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_setAuctionBetting.sql
--
-- Each character has at most one active bet (PK ownerid). Upsert the row and
-- return the ownerid on success — the caller treats this as a confirmation
-- ack to refresh the UI.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctionbetting(INTEGER, BIGINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setauctionbetting(
    _ownerid    INTEGER,
    _auctionid  BIGINT,
    _qina       BIGINT
)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_betting (ownerid, auctionid, qina)
    VALUES (_ownerid, _auctionid, _qina)
    ON CONFLICT (ownerid) DO UPDATE
        SET auctionid = EXCLUDED.auctionid,
            qina      = EXCLUDED.qina;
    RETURN _ownerid;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setauctionbetting(INTEGER, BIGINT, BIGINT);
-- +goose StatementEnd
