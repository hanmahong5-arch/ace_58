-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CheckMovableLegacyItems.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkmovablelegacyitems()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	DECLARE		_charcnt	int

	DECLARE		_itemcnt	int

	

    -- Insert statements for procedure here

    SELECT COUNT(*) INTO _charcnt FROM user_data WHERE delete_complete_date <> 0 AND delete_complete_date + 3600*24*90 < GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) AND item_legacy = 0

	SELECT _itemcnt = COUNT(*) FROM user_item WHERE (warehouse <> 3 AND warehouse <> 6 AND warehouse <> 7) AND char_id IN (SELECT char_id FROM user_data WHERE delete_complete_date <> 0 AND delete_complete_date + 3600*24*90 < GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0))
RAISE NOTICE '%', 'movable char count : ' + CAST(_charcnt AS nvarchar(20))+ ', item count : ' + CAST(_itemcnt AS nvarchar(20));

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkmovablelegacyitems;
-- +goose StatementEnd
