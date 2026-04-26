-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_CommentWrite.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_commentwrite(_user_id TEXT, _char_id INTEGER, _comment TEXT, _writer TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
insert into user_comment ( user_id, char_id, comment, writer)

values ( _user_id, _char_id, _comment, _writer)






IF @_e_r_r_o_r <> 0

	return 0



return @_i_d_e_n_t_i_t_y;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_commentwrite;
-- +goose StatementEnd
