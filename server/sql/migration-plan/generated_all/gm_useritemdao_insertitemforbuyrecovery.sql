-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertItemForBuyRecovery.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertitemforbuyrecovery(_char_id INTEGER, _warehouse INTEGER, _useditem_nameid INTEGER, _useditem_amount BIGINT, _server_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
INSERT user_item (char_id, name_id, slot_id, amount,tid,slot,warehouse,

		producer, expired_time,buy_amount, buy_duration,

		dynamic_property, server_of_origin)

VALUES (_char_id, _useditem_nameid, 0, _useditem_amount, 0, 0, _warehouse,

		'', 0, 0, 0,

		0, _server_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertitemforbuyrecovery;
-- +goose StatementEnd
