-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetHouseObjectUseCount.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_sethouseobjectusecount(_obj_id INTEGER, _char_id INTEGER, _use_count INTEGER, _next_reset_time BIGINT, _cur_owner_usecnt_per_day INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT obj_id FROM houseobject_extdata(UPDLOCK) where obj_id = _obj_id)

		BEGIN

			UPDATE houseobject_extdata

			SET	accumulated_usecount = _use_count,

				next_resettime_for_owner = _next_reset_time,

				cur_owner_usecnt_per_day = _cur_owner_usecnt_per_day

			WHERE obj_id = _obj_id

		END

	ELSE

		BEGIN

			INSERT houseobject_extdata(obj_id, char_id, accumulated_usecount, next_resettime_for_owner, cur_owner_usecnt_per_day)

			VALUES (_obj_id, _char_id, _use_count, _next_reset_time, _cur_owner_usecnt_per_day)

		END

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethouseobjectusecount;
-- +goose StatementEnd
