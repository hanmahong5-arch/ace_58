-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetBuddy_inter_130319.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getbuddy_inter_130319(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

    DECLARE _utc_adjust BIGINT

    _utc_adjust := GetUtcAdjustSecWithUTC_Local((NOW() AT TIME ZONE 'UTC'), NOW())		

	SELECT buddy_id, buddy_name, 0, 0, 0, 0, _utc_adjust, delete_flag, N'', 0, 0, -1, 0, server_id, COALESCE(comment, N'') FROM user_buddy_inter where char_id = _char_id

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getbuddy_inter_130319;
-- +goose StatementEnd
