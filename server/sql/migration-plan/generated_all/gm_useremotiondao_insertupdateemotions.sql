-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserEmotionDAO_InsertUpdateEmotions.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useremotiondao_insertupdateemotions(_char_id INTEGER, _emotion_type INTEGER, _expire_date INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	IF NOT EXISTS ( SELECT char_id FROM user_emotion (UPDLOCK) WHERE char_id = _char_id AND emotion_type = _emotion_type )

	BEGIN

		INSERT INTO user_emotion

		(

			char_id,

			emotion_type,

			expire_date

		)

		VALUES

		(

			_char_id,

			_emotion_type,

			_expire_date

		)

	END

	ELSE

	BEGIN

		UPDATE	user_emotion

		SET		expire_date = _expire_date

		WHERE	char_id = _char_id

		AND		emotion_type = _emotion_type

			

	END



	RETURN @_r_o_w_c_o_u_n_t



END /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useremotiondao_insertupdateemotions;
-- +goose StatementEnd
