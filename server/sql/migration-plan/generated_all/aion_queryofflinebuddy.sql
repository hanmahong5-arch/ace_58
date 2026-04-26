-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_QueryOfflineBuddy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_queryofflinebuddy(_charid INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	SELECT inviter_id, inviter_name, inviter_msg, userlevel, userclass, gender from user_buddy_offline with(nolock) where USER_ID = _charid and DATEDIFF(day, createdate, NOW())<= 7

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_queryofflinebuddy;
-- +goose StatementEnd
