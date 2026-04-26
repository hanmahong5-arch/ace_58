-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMonsterAchievement_Delete.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermonsterachievement_delete(_char_id INTEGER, _achieve_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	DELETE FROM user_monster_achievement WHERE char_id=_char_id and achieve_id=_achieve_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermonsterachievement_delete;
-- +goose StatementEnd
