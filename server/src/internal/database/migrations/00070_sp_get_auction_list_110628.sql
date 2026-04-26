-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port: aion_GetAuctionList_110628.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetAuctionList_110628.sql
--
-- Return all in-flight (state <= 1) auctions matching a (race,type) bucket.
-- Used by the housing UI auction list panel.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionlist_110628(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getauctionlist_110628(
    _race INTEGER,
    _type INTEGER
)
RETURNS TABLE (
    out_id          BIGINT,
    out_state       SMALLINT,
    out_goodsid     INTEGER,
    out_sellerid    INTEGER,
    out_sellername  TEXT,
    out_buyerid     INTEGER,
    out_buyername   TEXT,
    out_qina        BIGINT,
    out_stepqina    BIGINT,
    out_lastupdate  INTEGER,
    out_createtime  INTEGER,
    out_betcount    INTEGER,
    out_initqina    BIGINT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT  ua.id,
            ua.state,
            ua.goodsid,
            ua.sellerid,
            ua.sellername,
            ua.buyerid,
            ua.buyername,
            ua.qina,
            ua.stepqina,
            ua.lastupdate,
            ua.createtime,
            ua.betcount,
            ua.initqina
      FROM user_auction AS ua
     WHERE ua.type  = _type
       AND ua.race  = _race::SMALLINT
       AND ua.state <= 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionlist_110628(INTEGER, INTEGER);
-- +goose StatementEnd
