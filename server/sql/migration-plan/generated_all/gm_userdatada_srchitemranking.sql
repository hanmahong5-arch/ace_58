-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchItemRanking.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchitemranking(_item_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			SELECT sum(t1.amount) amount,t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.race, t2.class, t2.gender, t2.lev	

			from	user_item t1(nolock), user_data t2(nolock)

			where	t1.char_id = t2.char_id

			and		t1.name_id=_item_id

			group by t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.race, t2.class, t2.gender, t2.lev

			order by amount desc						

			
 /* LIMIT 100 appended */ LIMIT 100;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchitemranking;
-- +goose StatementEnd
