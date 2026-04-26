-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_AddItemAmount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_additemamount(_id BIGINT, _amount BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE user_item SET amount=amount + _amount WHERE id = _id

if (_amount < 0)

/*	DELETE FROM user_item WHERE id = _id AND amount <= 0 */

/*MARO:  "amount <= 0 " part is tricky, but must be HERE */

/* MARO: who did change this statement from DELETE ~ to UPDATE ~ ??? */

	-- except kina

	UPDATE user_item Set warehouse=10, update_date=NOW() WHERE id = _id AND amount <= 0 AND name_id <> 182400001;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_additemamount;
-- +goose StatementEnd
