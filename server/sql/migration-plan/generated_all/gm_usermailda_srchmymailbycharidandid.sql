-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserMailDA_SrchMyMailByCharIDandID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_usermailda_srchmymailbycharidandid(_char_id TEXT, _mail_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

				

			select	COALESCE(t2.name_id, 0) name_id, t1.id, t1.to_id, t1.to_name, t1.from_id, t1.from_name, t1.content, t1.title, t1.item_id, t1.item_nameid, t1.item_amount, t1.money, t1.state, t1.arrive_time, t1.express_mail, t1.abyss_point

			from	user_mail t1(nolock) 

			left outer join user_item t2(nolock) on t1.item_id=t2.id

			where	(t1.id = _mail_id) and (t1.from_id = _char_id or  t1.to_id = _char_id );
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_usermailda_srchmymailbycharidandid;
-- +goose StatementEnd
