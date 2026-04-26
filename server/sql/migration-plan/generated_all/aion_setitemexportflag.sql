-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemExportFlag.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemexportflag(_exportid BIGINT, _id BIGINT, _exportto INTEGER, _date INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	IF NOT EXISTS (SELECT id FROM user_item(updlock) WHERE id = _id AND export_id <> 0)

	BEGIN

		INSERT export_item_log(item_id, export_to_sv, export_to_id, export_date) VALUES (_id, _exportto, 0, _date)

		_exportid := @_i_d_e_n_t_i_t_y

		UPDATE user_item SET export_id = _exportid WHERE id = _id

	END

	ELSE

	BEGIN

		_exportid := 0

	END	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemexportflag;
-- +goose StatementEnd
