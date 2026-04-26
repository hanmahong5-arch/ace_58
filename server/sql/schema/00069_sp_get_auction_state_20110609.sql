-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port:
--   aion_getauctionstate_20110609.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/
--         aion_getauctionstate_20110609.sql
--
-- Single-row lookup of an auction's current bid + state by id.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionstate_20110609(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getauctionstate_20110609(_id BIGINT)
RETURNS TABLE (
    out_buyerid    INTEGER,
    out_buyername  TEXT,
    out_initqina   BIGINT,
    out_qina       BIGINT,
    out_state      SMALLINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT  ua.buyerid,
            ua.buyername,
            ua.initqina,
            ua.qina,
            ua.state
      FROM user_auction AS ua
     WHERE ua.id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionstate_20110609(BIGINT);
-- +goose StatementEnd
