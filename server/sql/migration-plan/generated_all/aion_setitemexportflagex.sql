-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemExportFlagEx.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemexportflagex(_exportid BIGINT, _id BIGINT, _exportto INTEGER, _exporttoid BIGINT, _date INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	IF EXISTS (SELECT id FROM export_item_log(updlock) WHERE id = _exportid)

		UPDATE export_item_log SET export_to_id = _exporttoid WHERE id = _exportid

	ELSE

	BEGIN

		INSERT export_item_log(item_id, export_to_sv, export_to_id, export_date) VALUES (_id, _exportto, _exporttoid, _date)

		UPDATE user_item SET export_id = @_i_d_e_n_t_i_t_y WHERE id = _id

	END	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemexportflagex;
-- +goose StatementEnd
