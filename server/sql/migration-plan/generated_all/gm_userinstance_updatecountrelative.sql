-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserInstance_UpdateCountRelative.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userinstance_updatecountrelative(_csv_ids TEXT, _char_id INTEGER, _count INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

			declare	_sql varchar(1000)

			_sql := 'UPDATE	user_instance '

						+ ' SET		count_variate = count_variate + ' + convert(varchar(30), _count)

						+ ' WHERE	char_id = ' + convert(varchar(30), _char_id)

						+ ' AND		id IN (' + _csv_ids + ') '

			exec (_sql)

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userinstance_updatecountrelative;
-- +goose StatementEnd
