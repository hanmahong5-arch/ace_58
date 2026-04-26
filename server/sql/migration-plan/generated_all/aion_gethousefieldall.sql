-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHouseFieldAll.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethousefieldall()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	SELECT id, addr_id, building_nameId, owner_id, owner_type, owner_race, state, permission, comment_state,

			roof, outwall, frame, door, garden, fence, 

			inwall1, inwall2, inwall3, inwall4, inwall5, inwall6, 

			infloor1, infloor2, infloor3, infloor4, infloor5, infloor6, 

			addon1, addon2, addon3, 

			flag1, flag2, flag3, flag4, flag5, flag6, flag7,

			COALESCE(comment, ''), COALESCE(owner_name, ''), legion_id, emblem_version, emblem_bgcolor

	FROM house_field

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethousefieldall;
-- +goose StatementEnd
