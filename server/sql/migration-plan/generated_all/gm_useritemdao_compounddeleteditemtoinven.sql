-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_CompoundDeletedItemToInven.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_compounddeleteditemtoinven(_main_item_dbid BIGINT, _char_id INTEGER, _return_value INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _error			INT

DECLARE _count		INT

_return_value := 0



UPDATE user_item SET warehouse=16

WHERE id  = (SELECT id FROM user_item (nolock) WHERE char_id=_char_id AND main_item_dbid=_main_item_dbid AND warehouse=17 order by update_date desc)

AND 0 = (select count(*) FROM user_item (nolock) WHERE char_id=_char_id AND main_item_dbid=_main_item_dbid AND warehouse=16)



SELECT @_e_r_r_o_r, _count = @_r_o_w_c_o_u_n_t

IF _error <> 0 OR _count < 1

	RETURN



_return_value := 1

RETURN /* LIMIT 1 appended */ LIMIT 1 INTO _error;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_compounddeleteditemtoinven;
-- +goose StatementEnd
