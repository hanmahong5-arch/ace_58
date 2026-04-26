-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemPolishInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitempolishinfo(_dbid BIGINT, _tool_name_id INTEGER, _option INTEGER, _count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    update user_item_polish set name_id = _tool_name_id, random_id=_option, polish_point=_count where id=_dbid

    

    if @_r_o_w_c_o_u_n_t <=0

		insert into user_item_polish (id, name_id, random_id, polish_point) values (_dbid, _tool_name_id, _option, _count)

		

	/*

	if EXISTS (SELECT id FROM user_item_polish (UPDLOCK) WHERE id=_dbid) 

	begin

		update user_item_polish set name_id = _tool_name_id, random_id=_option, polish_point=_count where id=_dbid

	end

	else

	begin

		insert into user_item_polish (id, name_id, random_id, polish_point) values (_dbid, _tool_name_id, _option, _count)

	end

	*/

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitempolishinfo;
-- +goose StatementEnd
