-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserCreativityDA_ResetMyCPUsageByCharID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usercreativityda_resetmycpusagebycharid(_char_id TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	UPDATE	user_use_cp

	SET		value = 0, accumulated_cp = 0, data_id = 0

	WHERE	char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usercreativityda_resetmycpusagebycharid;
-- +goose StatementEnd
