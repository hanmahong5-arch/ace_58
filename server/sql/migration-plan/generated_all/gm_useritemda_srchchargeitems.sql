-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchChargeItems.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchchargeitems(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select t2.id, t2.charge_point

			from user_item t1(nolock), user_item_charge t2(nolock)

			where t1.char_id=_char_id

			and t1.id=t2.id

			and t1.warehouse!=10

			and t1.warehouse!=11

			and t1.warehouse!=17

			and t1.warehouse!=18

			and t1.warehouse!=19

			and t1.warehouse!=20;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchchargeitems;
-- +goose StatementEnd
