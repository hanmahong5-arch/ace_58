-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_DeleteChargePoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_deletechargepoint(_id BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
/*----------------------------------------------------------------------

기  능 : 아이템 내구도 삭제

테스트 :

	EXEC GM_UserItemDAO_DeleteChargePoint _id=3614189

----------------------------------------------------------------------*/



BEGIN



	DELETE FROM	user_item_charge

	WHERE	id = _id



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_deletechargepoint;
-- +goose StatementEnd
