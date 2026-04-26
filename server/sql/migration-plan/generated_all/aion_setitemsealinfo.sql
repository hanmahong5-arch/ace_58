-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemSealInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemsealinfo(_char_id INTEGER, _item_id BIGINT, _seal_state INTEGER, _expired_time INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.




    -- Insert statements for procedure here

	IF EXISTS (SELECT id FROM user_item_sealed(updlock) WHERE id = _item_id)

		UPDATE user_item_sealed SET sealExpiredTime = _expired_time, sealState = _seal_state, char_id = _char_id WHERE id = _item_id

	ELSE

		INSERT INTO user_item_sealed (id, sealExpiredTime, sealState, char_id) VALUES (_item_id, _expired_time, _seal_state, _char_id)

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemsealinfo;
-- +goose StatementEnd
