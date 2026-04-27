-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) port: aion_GetHighestLevelCharacterOfAccount.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetHighestLevelCharacterOfAccount.sql
--
-- T-SQL body uses ROW_NUMBER() OVER (PARTITION BY account_id
-- ORDER BY lev DESC, char_id ASC) and filters rank_lev=1 — i.e. one row
-- per account, the highest-level non-deleted character (ties broken by
-- earliest char_id).
--
-- @accountNum=0 returns one row per account on the shard (used by ranking
-- snapshots); non-zero returns one row for that single account (used by
-- character-select hint).
--
-- T-SQL → PG translation: ROW_NUMBER() and PARTITION BY are identical in
-- syntax. The `with(nolock)` hint is dropped (PG snapshot isolation makes
-- it unnecessary — we already get a consistent read-committed snapshot).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethighestlevelcharacterofaccount(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethighestlevelcharacterofaccount(_account_num INTEGER)
RETURNS TABLE (
    game_account_no INTEGER,
    game_server_no  SMALLINT,
    character_id    INTEGER,
    character_level INTEGER
)
LANGUAGE plpgsql AS $$
BEGIN
    IF _account_num = 0 THEN
        RETURN QUERY
            SELECT u1.account_id, u1.org_server, u1.char_id, u1.lev
              FROM (
                  SELECT ROW_NUMBER() OVER (PARTITION BY ud.account_id
                                            ORDER BY ud.lev DESC, ud.char_id ASC) AS rank_lev,
                         ud.account_id, ud.org_server, ud.char_id, ud.lev
                    FROM user_data ud
                   WHERE ud.delete_complete_date = 0
              ) u1
             WHERE u1.rank_lev = 1;
    ELSE
        RETURN QUERY
            SELECT u1.account_id, u1.org_server, u1.char_id, u1.lev
              FROM (
                  SELECT ROW_NUMBER() OVER (PARTITION BY ud.account_id
                                            ORDER BY ud.lev DESC, ud.char_id ASC) AS rank_lev,
                         ud.account_id, ud.org_server, ud.char_id, ud.lev
                    FROM user_data ud
                   WHERE ud.delete_complete_date = 0
                     AND ud.account_id           = _account_num
              ) u1
             WHERE u1.rank_lev = 1;
    END IF;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethighestlevelcharacterofaccount(INTEGER);
-- +goose StatementEnd
