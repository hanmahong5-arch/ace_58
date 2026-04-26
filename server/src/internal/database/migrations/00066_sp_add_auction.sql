-- AionCore 5.8 — Sprint 1.1a Round 7 (Track B5) port: aion_addAuction.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_addAuction.sql
--
-- List a new house for auction. Returns:
--   0  → blocked (already in-flight, or in filter list)
--  >0  → newly inserted user_auction.id
--
-- T-SQL `return @@IDENTITY` becomes RETURNING id in PG.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauction(INTEGER, INTEGER, INTEGER, INTEGER, TEXT, BIGINT, BIGINT, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addauction(
    _type        INTEGER,
    _race        INTEGER,
    _name_id     INTEGER,
    _seller_id   INTEGER,
    _seller_name TEXT,
    _qina        BIGINT,
    _step_qina   BIGINT,
    _create_time INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _new_id BIGINT;
BEGIN
    -- block if either: this name_id is already in an in-flight auction (state 0/1)
    -- or it is in the filter list.
    IF EXISTS (SELECT 1 FROM user_auction WHERE goodsid = _name_id AND state IN (0, 1))
       OR EXISTS (SELECT 1 FROM user_auctionfilter WHERE goodsid = _name_id) THEN
        RETURN 0;
    END IF;

    INSERT INTO user_auction
           (type, race, goodsid, sellerid, sellername,
            initqina, qina, stepqina, state,
            buyerid, buyername, lastupdate, createtime)
    VALUES (_type, _race::SMALLINT, _name_id, _seller_id, _seller_name,
            _qina, _qina, _step_qina, 0,
            0, '', 0, _create_time)
    RETURNING id INTO _new_id;

    RETURN _new_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addauction(INTEGER, INTEGER, INTEGER, INTEGER, TEXT, BIGINT, BIGINT, INTEGER);
-- +goose StatementEnd
