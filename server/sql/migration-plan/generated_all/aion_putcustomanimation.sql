-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutCustomAnimation.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcustomanimation(_char_id INTEGER, _animation_id INTEGER, _animation_type INTEGER, _expire_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.

	

    -- Insert statements for procedure here

    Update user_customAnimation set useState = 0 where char_id = _char_id and animation_type= _animation_type and useState != 0

    Update user_customAnimation Set animation_type=_animation_type, expire_time=_expire_time, useState=1	Where char_id=_char_id and animation_id=_animation_id

    

    if @_r_o_w_c_o_u_n_t = 0

		Insert into user_customAnimation (char_id, animation_id, animation_type, expire_time, useState) 

				values(_char_id, _animation_id, _animation_type, _expire_time, 1)			    

	

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcustomanimation;
-- +goose StatementEnd
