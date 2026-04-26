-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchUserExtraInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchuserextrainfo(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	set transaction isolation level read uncommitted

	

	SELECT	char_id, use_bot_channel, COALESCE(use_bot_channel_update_date, '1900-01-01') as use_bot_channel_update_date, COALESCE(account_id, 0) as account_id, vip_icon

			, COALESCE(prevSeasonReward, 0) as prevSeasonReward, COALESCE(currentSeasonReward, 0) as currentSeasonReward

	FROM	user_extra_info

	WHERE	char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchuserextrainfo;
-- +goose StatementEnd
