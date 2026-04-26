-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_PutPollAnswer_110404.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putpollanswer_110404(_poll_id INTEGER, _real_poll_id INTEGER, _char_id INTEGER, _char_name TEXT, _account_id INTEGER, _account_name TEXT, _class INTEGER, _race INTEGER, _world INTEGER, _xlocation DOUBLE PRECISION, _ylocation DOUBLE PRECISION, _zlocation DOUBLE PRECISION, _level INTEGER, _answer TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
insert into poll_answer (poll_Id, char_id, user_id, account_id, account_name, class, race, world, xlocation, ylocation, zlocation, lev, answer_time, answer, real_poll_id)

values (_poll_id, _char_id, _char_name, _account_id, _account_name, _class, _race,

	 _world, _xlocation, _ylocation, _zlocation,_level, NOW(), _answer, _real_poll_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putpollanswer_110404;
-- +goose StatementEnd
