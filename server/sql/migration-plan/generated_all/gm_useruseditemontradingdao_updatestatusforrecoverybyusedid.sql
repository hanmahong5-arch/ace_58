-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserUseditemOnTradingDAO_UpdateStatusForRecoveryByUsedId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useruseditemontradingdao_updatestatusforrecoverybyusedid(_used_id INTEGER, _status INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
update user_useditem_ontrading set status=_status

where used_id=_used_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useruseditemontradingdao_updatestatusforrecoverybyusedid;
-- +goose StatementEnd
