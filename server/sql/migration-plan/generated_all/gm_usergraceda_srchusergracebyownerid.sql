-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserGraceDA_SrchUserGraceByOwnerID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usergraceda_srchusergracebyownerid(_owner_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	grace_id, owner_id, goods_id, building_id, startTime, state

	FROM	user_grace (nolock)

	WHERE	owner_id = _owner_id

	ORDER BY grace_id DESC




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usergraceda_srchusergracebyownerid;
-- +goose StatementEnd
