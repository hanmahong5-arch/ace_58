-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserCustomAnimationDAO_InsertUpdateAnimation.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usercustomanimationdao_insertupdateanimation(_char_id INTEGER, _animation_id INTEGER, _animation_type INTEGER, _state INTEGER, _expire_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
IF NOT EXISTS ( SELECT 1 FROM user_customAnimation (nolock) WHERE char_id = _char_id AND animation_id = _animation_id )

	BEGIN

		INSERT INTO user_customAnimation

		(

			char_id,	

			animation_id, 

			animation_type,	

			useState, 

			expire_time

		)

		VALUES

		(

			_char_id, 

			_animation_id, 

			_animation_type, 

			_state, 

			_expire_time

		)

	END

	ELSE

	BEGIN

		UPDATE	user_customAnimation

		SET		animation_type = _animation_type, 

				useState = _state, 

				expire_time = _expire_time

		WHERE	char_id = _char_id

		AND		animation_id = _animation_id

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usercustomanimationdao_insertupdateanimation;
-- +goose StatementEnd
