-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserRecoveryInfoDAO_Insert.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userrecoveryinfodao_insert(_char_id INTEGER, _recovery_status INTEGER, _return_value INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _error INT

DECLARE _count INT



_return_value := 0



if EXISTS (SELECT char_id FROM user_recovery_info (UPDLOCK) WHERE char_id=_char_id) 

	begin

		UPDATE user_recovery_info

		SET recovery_status = _recovery_status

		WHERE char_id=_char_id

	end

else

	begin

		INSERT into user_recovery_info(char_id, recovery_status)

		VALUES (_char_id, _recovery_status)

	end



SELECT @_e_r_r_o_r, _count = @_r_o_w_c_o_u_n_t

IF _error <> 0 OR _count < 1

	RETURN



_return_value := 1

RETURN INTO _error;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userrecoveryinfodao_insert;
-- +goose StatementEnd
