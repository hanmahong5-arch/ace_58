-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemImportFlag.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemimportflag(_importid BIGINT, _id BIGINT, _importfrom INTEGER, _importfromid BIGINT, _date INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    IF NOT EXISTS (SELECT id FROM user_item(updlock) WHERE id = _id AND import_id <> 0)

	BEGIN

		INSERT import_item_log(item_id, import_from_sv, import_from_id, import_date) VALUES (_id, _importfrom, _importfromid, _date)

		_importid := @_i_d_e_n_t_i_t_y

		UPDATE user_item SET import_id = _importid WHERE id = _id

	END

	ELSE

	BEGIN

		_importid := 0

	END	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemimportflag;
-- +goose StatementEnd
