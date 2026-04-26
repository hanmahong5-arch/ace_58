-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserChatAccusedDAO_InsertUpdate.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userchataccuseddao_insertupdate(_char_id INTEGER, _accused_count INTEGER, _penalty_start_time INTEGER, _accused_count_penalty INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



			UPDATE	user_chat_accused

			SET		accused_count			= _accused_count

					, penalty_start_time	= _penalty_start_time

					, accused_count_penalty	= _accused_count_penalty

			WHERE	char_id = _char_id

			

			IF (@_r_o_w_c_o_u_n_t = 0)

			BEGIN

				INSERT INTO user_chat_accused (char_id, accused_count, penalty_start_time, accused_count_penalty, last_accused_time)

				VALUES (_char_id, _accused_count, _penalty_start_time, _accused_count_penalty, 0)

			END

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userchataccuseddao_insertupdate;
-- +goose StatementEnd
