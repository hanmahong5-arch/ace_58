-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGloryPointInfo_20160415.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setglorypointinfo_20160415(_char_id INTEGER, _glory_point INTEGER, _today_glory_point INTEGER, _this_week_glory_point INTEGER, _last_week_glory_point INTEGER, _two_weeks_ago_glory_point INTEGER, _three_weeks_ago_glory_point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




	-- Update user_gp table

	IF EXISTS (SELECT glory_point FROM user_gp_data WHERE char_id=_char_id)

	BEGIN

		UPDATE user_gp_data SET glory_point = _glory_point WHERE char_id=_char_id

	END

	ELSE

	BEGIN

		-- table에 추가하는 경우는 gp값이 0 이상인 경우로 한정.

		IF (_glory_point > 0)

		BEGIN

			INSERT INTO user_gp_data (char_id, glory_point, ownership_bonus_gp) VALUES (_char_id, _glory_point, 0)

		END

	END



	-- Update user_data table			

	UPDATE user_data SET today_glory_point=_today_glory_point, this_week_glory_point=_this_week_glory_point, last_week_glory_point=_last_week_glory_point, two_weeks_ago_glory_point = _two_weeks_ago_glory_point, three_weeks_ago_glory_point = _three_weeks_ago_glory_point WHERE char_id=_char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setglorypointinfo_20160415;
-- +goose StatementEnd
