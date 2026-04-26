-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserPunishmentDAO_AddModPunishForBot.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userpunishmentdao_addmodpunishforbot(_account_id INTEGER, _char_id INTEGER, _play_block INTEGER, _status INTEGER, _punish_code INTEGER, _start_date TIMESTAMPTZ, _end_date TIMESTAMPTZ, _punish_min INTEGER, _cancel_date TIMESTAMPTZ, _cancel_reason TEXT, _punish_reason TEXT, _login_id TEXT, _login_nm TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	

	IF NOT EXISTS ( SELECT 1 FROM user_punishment WHERE account_id = _account_id AND char_id = _char_id )

	BEGIN

		INSERT INTO user_punishment

		(

			account_id,

			char_id,

			play_block,

			status,

			punish_code,

			start_date,	

			end_date,

			remain_minute,

--			cancel_date,

--			cancel_reason,

			punish_reason,

			login_id,	

			login_nm

		)

		VALUES

		(

			_account_id,

			_char_id,

			_play_block,

			_status,

			_punish_code,

			NOW(),	

			DATEADD(minute, _punish_min, NOW()),

			_punish_min,

--			_cancel_date,

--			_cancel_reason,

			_punish_reason,

			_login_id,	

			_login_nm

		)

	END

	ELSE

	BEGIN

		UPDATE	user_punishment

		SET		punish_code = _punish_code

		WHERE	account_id = _account_id AND char_id = _char_id

	END



	RETURN @_r_o_w_c_o_u_n_t



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userpunishmentdao_addmodpunishforbot;
-- +goose StatementEnd
