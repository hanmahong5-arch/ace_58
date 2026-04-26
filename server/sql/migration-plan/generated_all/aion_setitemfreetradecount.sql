-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemFreeTradeCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemfreetradecount(_dbid BIGINT, _tool_name_id INTEGER, _count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




     -- Insert statements for procedure here

    update user_item_freetrade set freeTradeState=_count where id=_dbid

    

    if @_r_o_w_c_o_u_n_t <=0

		insert into user_item_freetrade (id, name_id, freeTradeState) values (_dbid, _tool_name_id,_count)

		

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemfreetradecount;
-- +goose StatementEnd
