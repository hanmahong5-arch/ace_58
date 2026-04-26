-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMailDA_SrchMyMail.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermailda_srchmymail(_char_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select	id, to_id, to_name, from_id, from_name, title, content, item_id, item_nameid, item_amount, money, state, arrive_time, express_mail, item_tid, abyss_point

			from	user_mail (nolock)

			where	to_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermailda_srchmymail;
-- +goose StatementEnd
