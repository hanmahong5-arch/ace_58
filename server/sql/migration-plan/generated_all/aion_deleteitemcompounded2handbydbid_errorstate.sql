-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_DeleteItemCompounded2HandByDbId_ErrorState.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_deleteitemcompounded2handbydbid_errorstate(_id BIGINT, _warehouse INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
declare _ret int



/*DELETE FROM user_item_compounded_twohand WHERE id = _id*/




	-- 에러 상태로 바꾸는 거라 update_date는 변경 안 시킴, 조사용으로 필요해보임

	UPDATE user_item SET warehouse = _warehouse, dynamic_property=(dynamic_property|8)  WHERE id = _id




return _ret;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deleteitemcompounded2handbydbid_errorstate;
-- +goose StatementEnd
