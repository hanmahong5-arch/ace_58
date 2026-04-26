-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetUsingDirectPortalInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setusingdirectportalinfo(_char_id INTEGER, _d_p_id INTEGER, _world INTEGER, _x_location DOUBLE PRECISION, _y_location DOUBLE PRECISION, _z_location DOUBLE PRECISION)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	IF EXISTS (SELECT char_id FROM user_dportal(updlock) WHERE char_id = _char_id)

		UPDATE user_dportal SET dpId = _d_p_id, lastdp_world = _world, lastdp_xlocation = _x_location, lastdp_ylocation = _y_location, lastdp_zlocation = _z_location WHERE char_id = _char_id

	ELSE

		INSERT INTO user_dportal VALUES (_char_id, _d_p_id, _world, _x_location, _y_location, _z_location)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setusingdirectportalinfo;
-- +goose StatementEnd
