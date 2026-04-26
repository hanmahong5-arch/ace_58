-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetSPList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getsplist()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT name, create_date, modify_date FROM sys.procedures where name not like 'GM_%' AND name != 'AIONMO_CharacterInfo_SrchCharListByUserId'  and name != 'total_qina' and name not like 'MO_%' ORDER BY name DESC

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getsplist;
-- +goose StatementEnd
