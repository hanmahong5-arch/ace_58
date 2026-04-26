-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_getauctionstate_20110609.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getauctionstate_20110609(_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	select buyerid, buyername, InitQina, qina, state from user_auction with(nolock) where ID=_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getauctionstate_20110609;
-- +goose StatementEnd
