-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetHighestLevelCharacterOfAccount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethighestlevelcharacterofaccount(_account_num INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	IF _account_num = 0

	Begin

		SELECT u1.account_id as gameAccountNo, u1.org_server as gameServerNo, u1.char_id as characterId, u1.lev as characterLevel

		FROM (

			select row_number() over (partition by account_id order by lev desc, char_id asc) as rank_lev, account_id, org_server, char_id, lev

			from user_data with (nolock) Where delete_complete_date=0

			) as u1

		WHERE u1.rank_lev=1 

	End

	ELSE

	Begin

		SELECT u1.account_id as gameAccountNo, u1.org_server as gameServerNo, u1.char_id as characterId, u1.lev as characterLevel

		FROM (

			select row_number() over (partition by account_id order by lev desc, char_id asc) as rank_lev, account_id, org_server, char_id, lev

			from user_data with (nolock) Where delete_complete_date=0 and account_id=_account_num

			) as u1

		WHERE u1.rank_lev=1

	End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethighestlevelcharacterofaccount;
-- +goose StatementEnd
