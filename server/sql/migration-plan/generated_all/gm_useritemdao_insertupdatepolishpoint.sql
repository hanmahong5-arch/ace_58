-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertUpdatePolishPoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertupdatepolishpoint(_id BIGINT, _polish_name_id INTEGER, _random_id INTEGER, _polish_point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	IF NOT EXISTS ( SELECT id FROM user_item_polish WHERE id = _id )

	BEGIN

		INSERT INTO user_item_polish (id, name_id, random_id, polish_point) 

		VALUES (_id, _polish_name_id, _random_id, _polish_point)

	END

	ELSE

	BEGIN

		UPDATE	user_item_polish

		SET		name_id = _polish_name_id,

				random_id = _random_id,

				polish_point = _polish_point

		WHERE	id = _id

	END



	RETURN @_r_o_w_c_o_u_n_t



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertupdatepolishpoint;
-- +goose StatementEnd
