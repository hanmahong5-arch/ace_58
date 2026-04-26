-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetTownData.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_settowndata(_town_id INTEGER, _point INTEGER, _last_lv_changed_time INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




    -- Insert statements for procedure here

	IF EXISTS (SELECT town_id FROM town_data(updlock) WHERE town_id = _town_id)

		UPDATE town_data

		SET point = _point,

			lastLvChangedTime = _last_lv_changed_time		

		WHERE town_id = _town_id

	ELSE

		INSERT town_data VALUES (_town_id, _point, _last_lv_changed_time)

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_settowndata;
-- +goose StatementEnd
