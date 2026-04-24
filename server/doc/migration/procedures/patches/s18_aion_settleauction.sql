-- Phase S-18: aion_settleauction + aion_addkinahuser
--
-- Auction-expiry settlement chain called by the Lua worker
-- scripts/events/on_auction_expire.lua. The original NCSoft catalog ships
-- aion_updateauctionstate / aion_setauctionbetting / aion_setauctiongrace but
-- has NO single atomic "resolve this listing" SP — settlement was handled in
-- C++ server code. This patch introduces the missing contract.
--
-- Schema facts (aion_world_live.sql):
--   user_auction(id, type, race, goodsid, sellerid, sellername, buyerid,
--                buyername, initqina, qina, stepqina, state, lastupdate,
--                createtime, betcount)
--   user_betting(ownerid, auctionid, qina)               -- individual bids
--   user_item(id, char_id, name_id, amount, ...)         -- kinah = name_id 182400001
--   user_mail(id, to_id, to_name, from_id, from_name, title, content,
--             item_id, item_nameid, item_amount, money, state, arrive_time,
--             express_mail, item_tid, abyss_point)
--
-- Outcome codes returned to Lua:
--   0 = no_bids       → goods mailed back to seller, listing flagged settled
--   1 = sold          → item+kinah mails dispatched, listing flagged settled
--   2 = already       → listing already in terminal state; idempotent no-op
--   3 = missing       → listing row does not exist (stale expiry trigger)
--
-- Sentinel state: user_auction.state is integer; NCSoft uses 0 (active),
-- 1 (buyer-won), 9/10 (house-auction variants). We pick 99 as "settled by
-- AionCore S-18 job" — safely above any NCSoft enum value and trivially
-- greppable in production data. All settled rows keep state=99.
--
-- Concurrency: FOR UPDATE SKIP LOCKED on the listing row guarantees two
-- parallel expiry jobs cannot both process the same listing. The lock-loser
-- observes a zero-row cursor and returns outcome_code=2 (already settled)
-- once the winner has committed; strict-read-committed semantics make this
-- path idempotent even under a retrying asynq queue.

-- Thin kinah SP: add (possibly negative) delta to a character's kinah stack,
-- returning the new balance. Returns -1 when a negative delta would underflow.
DROP FUNCTION IF EXISTS aion_addkinahuser(integer, bigint);
CREATE OR REPLACE FUNCTION aion_addkinahuser(
    p_char_id integer,
    p_delta   bigint
) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
    v_new_balance bigint;
BEGIN
    -- Kinah lives in user_item as a singleton row keyed by name_id=182400001
    -- in the player's primary inventory (warehouse=0). We update in-place and
    -- return the post-delta amount atomically to the caller.
    UPDATE user_item
       SET amount      = amount + p_delta,
           update_date = CURRENT_TIMESTAMP
     WHERE char_id   = p_char_id
       AND name_id   = 182400001
       AND warehouse = 0
       AND amount + p_delta >= 0
     RETURNING amount INTO v_new_balance;

    IF v_new_balance IS NULL THEN
        -- Either no kinah row yet OR the delta would underflow. The caller
        -- (settlement SP) only ever calls us with a positive delta, so this
        -- branch signals "no kinah row exists" — auto-seed one when delta>=0.
        IF p_delta >= 0 THEN
            INSERT INTO user_item(id, char_id, name_id, slot_id, amount, slot,
                                  warehouse, producer)
            VALUES (nextval('user_item_id_seq'), p_char_id, 182400001, -1,
                    p_delta, 0, 0, 'auction')
            ON CONFLICT DO NOTHING
            RETURNING amount INTO v_new_balance;
            IF v_new_balance IS NULL THEN
                RETURN -1;  -- sequence missing or race; caller logs+aborts
            END IF;
            RETURN v_new_balance;
        END IF;
        RETURN -1;
    END IF;

    RETURN v_new_balance;
END;
$$;


-- Atomic auction settlement: lock the listing, pick the winning bid (if any),
-- flip the listing to settled, and dispatch payout mail(s) inside the same
-- transaction. Callable repeatedly on the same listing_id without double-pay.
DROP FUNCTION IF EXISTS aion_settleauction(bigint);
CREATE OR REPLACE FUNCTION aion_settleauction(
    p_listing_id bigint
) RETURNS TABLE(
    winner_cid   integer,
    seller_cid   integer,
    item_id      bigint,
    item_count   bigint,
    final_bid    bigint,
    outcome_code integer
)
LANGUAGE plpgsql AS $$
DECLARE
    v_row         user_auction%ROWTYPE;
    v_seller_name varchar(20);
    v_winner_name varchar(20);
    v_now         integer := EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::integer;
    v_title       varchar(20);
    v_body        varchar(1000);
BEGIN
    -- SKIP LOCKED converts a concurrent duplicate expiry into a clean no-op
    -- (v_row stays unset), which we surface as outcome_code=2.
    SELECT * INTO v_row
      FROM user_auction
     WHERE id = p_listing_id::integer
       FOR UPDATE SKIP LOCKED;

    IF NOT FOUND THEN
        -- Distinguish "row genuinely missing" vs "row locked by twin worker":
        -- a secondary probe without SKIP LOCKED tells us which.
        IF EXISTS (SELECT 1 FROM user_auction WHERE id = p_listing_id::integer) THEN
            -- Lock held by twin; caller should log as idempotent skip.
            RETURN QUERY SELECT 0, 0, 0::bigint, 0::bigint, 0::bigint, 2;
            RETURN;
        END IF;
        RETURN QUERY SELECT 0, 0, 0::bigint, 0::bigint, 0::bigint, 3;
        RETURN;
    END IF;

    -- Already in our terminal sentinel state → caller already ran this path.
    IF v_row.state = 99 THEN
        RETURN QUERY SELECT COALESCE(v_row.buyerid, 0), v_row.sellerid,
                            v_row.goodsid::bigint, 1::bigint,
                            v_row.qina, 2;
        RETURN;
    END IF;

    -- Truncate names to the 20-char mail column width; NCSoft stores longer
    -- names in user_auction(varchar(64)) so we defensively SUBSTR.
    v_seller_name := SUBSTR(COALESCE(v_row.sellername, ''), 1, 20);
    v_winner_name := SUBSTR(COALESCE(v_row.buyername,  ''), 1, 20);

    IF v_row.buyerid IS NULL OR v_row.buyerid = 0 THEN
        -- No bids: return the goods to the seller via system mail, no kinah.
        v_title := 'Auction Expired';
        v_body  := 'Your auction listing expired with no bidders. The item is returned.';
        PERFORM aion_mailwritesys_20111227(
            v_row.sellerid, v_seller_name,
            0, 'System',
            v_title, v_body,
            0::bigint,        -- item_id (unused for system-mail)
            v_row.goodsid,    -- item_nameid
            1::bigint,        -- item_amount (NCSoft house-auctions always 1)
            0::bigint,        -- money
            0, v_now, 0);

        UPDATE user_auction
           SET state = 99, lastupdate = v_now
         WHERE id = v_row.id;

        RETURN QUERY SELECT 0, v_row.sellerid,
                            v_row.goodsid::bigint, 1::bigint,
                            0::bigint, 0;
        RETURN;
    END IF;

    -- Winning path: item to buyer, kinah to seller. Two separate system mails
    -- keep attachment semantics identical to the NCSoft C++ payout flow.
    v_title := 'Auction Won';
    v_body  := 'Congratulations! You have won the auction. The item is attached.';
    PERFORM aion_mailwritesys_20111227(
        v_row.buyerid, v_winner_name,
        0, 'System',
        v_title, v_body,
        0::bigint, v_row.goodsid, 1::bigint,
        0::bigint, 0, v_now, 0);

    v_title := 'Auction Sold';
    v_body  := 'Your auction has been sold. Sale proceeds are attached.';
    PERFORM aion_mailwritesys_20111227(
        v_row.sellerid, v_seller_name,
        0, 'System',
        v_title, v_body,
        0::bigint, 0::integer, 0::bigint,
        v_row.qina,                  -- money = final bid, paid to seller
        0, v_now, 0);

    UPDATE user_auction
       SET state = 99, lastupdate = v_now
     WHERE id = v_row.id;

    RETURN QUERY SELECT v_row.buyerid, v_row.sellerid,
                        v_row.goodsid::bigint, 1::bigint,
                        v_row.qina, 1;
END;
$$;
