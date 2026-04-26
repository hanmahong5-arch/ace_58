-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserUseditemOnTradingDAO_UpdateStatusForBuyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useruseditemontradingdao_updatestatusforbuyrecovery(_char_id INTEGER, _name_id INTEGER, _status INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
update user_useditem_ontrading set status=_status

where used_id=(

SELECT target_item.used_id from (

select ROW_NUMBER() over (PARTITION BY uuo.used_id order by ui.create_date desc) rnk, uuo.used_id

from user_item ui join user_useditem_ontrading uuo on ui.name_id=uuo.tradeitemid

where ui.char_id=uuo.char_id

and ui.char_id=_char_id

and name_id=_name_id

and trade_type=1

and status=0

and DATEDIFF(SECOND, ui.create_date, uuo.regdate) between -1 and 2

) target_item

where target_item.rnk = 1

order by target_item.used_id desc) /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useruseditemontradingdao_updatestatusforbuyrecovery;
-- +goose StatementEnd
