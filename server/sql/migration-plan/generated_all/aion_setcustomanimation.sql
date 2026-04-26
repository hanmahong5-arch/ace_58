-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetCustomAnimation.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setcustomanimation(_char_id INTEGER, _animation_id INTEGER, _animation_type INTEGER, _command_type INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	if _command_type = 4	-- CUSTOM_ANIM_USE

	Begin

		Update user_customAnimation Set useState=0 

			Where char_id=_char_id and animation_type=_animation_type

		Update user_customAnimation Set useState=1

				Where char_id=_char_id and animation_id=_animation_id

	end



	if _command_type = 6 -- CUSTOM_ANIM_EXPIRE

	Begin

		Update user_customAnimation Set useState=0, expire_time=0

				Where char_id=_char_id and animation_id=_animation_id

	end

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setcustomanimation;
-- +goose StatementEnd
