-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetLastTransformId.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setlasttransformid(_char_id INTEGER, _last_transform_id INTEGER, _last_transform_scroll_id INTEGER, _last_collection_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN




	IF EXISTS (SELECT char_id FROM user_data_ext(UPDLOCK) where char_id = _char_id)

		BEGIN

			UPDATE user_data_ext 

			SET last_transform_id = _last_transform_id, last_transform_scroll_id = _last_transform_scroll_id, last_collection_id = _last_collection_id

			WHERE char_id = _char_id

		END

	ELSE

		BEGIN

			INSERT into user_data_ext (char_id, last_transform_id, last_transform_scroll_id, last_collection_id)

			VALUES (_char_id, _last_transform_id, _last_transform_scroll_id, _last_collection_id)

		END

		


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setlasttransformid;
-- +goose StatementEnd
