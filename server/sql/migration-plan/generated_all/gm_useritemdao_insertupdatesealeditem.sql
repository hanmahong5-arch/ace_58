-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertUpdateSealedItem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertupdatesealeditem(_id BIGINT, _seal_expired_time INTEGER, _seal_state INTEGER, _char_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
IF NOT EXISTS ( SELECT 1 FROM user_item_sealed WHERE id = _id )

	BEGIN

		INSERT INTO user_item_sealed

		VALUES

		(

			_id, 

			_seal_expired_time,

			_seal_state,

			_char_id

		)

	END

	ELSE

	BEGIN

		UPDATE	user_item_sealed

		SET		sealExpiredTime = _seal_expired_time,

				sealState = _seal_state,

				char_id = _char_id

		WHERE	id = _id

	END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertupdatesealeditem;
-- +goose StatementEnd
