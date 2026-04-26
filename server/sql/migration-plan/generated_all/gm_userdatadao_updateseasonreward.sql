-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDAO_UpdateSeasonReward.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatadao_updateseasonreward(_char_id INTEGER, _reward INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	UPDATE	user_extra_info

	SET		currentSeasonReward = _reward

	FROM	user_extra_info (nolock)

	WHERE	char_id = _char_id




END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatadao_updateseasonreward;
-- +goose StatementEnd
