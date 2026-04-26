-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserEscrowDA_SrchEscrowByCharIDandState.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userescrowda_srchescrowbycharidandstate(_char_id INTEGER, _state INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted



	SELECT	id, seller, qina, itemid, itemamount, buyer, state, registerdate, completedate

	FROM	user_escrow (nolock)

	WHERE	seller = _char_id and state=_state




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userescrowda_srchescrowbycharidandstate;
-- +goose StatementEnd
