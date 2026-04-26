-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserDataDA_SrchBotPointRanking.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userdatada_srchbotpointranking()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			SELECT row_number() over (order by bot_point desc ) as ranking , bot_point, accused_count,  

			org_server, char_id, user_id, account_id, account_name, t1.race, class, convert(tinyint, gender) gender, lev, guild_id,

			t3.name, convert(nvarchar,last_logout_time,20) last_logout_time

			from user_data t1(nolock) left outer join guild t3(nolock) on t1.guild_id=t3.id

			where delete_date=0 and bot_point !=0 and (account_punishment is null or account_punishment != 100) and datediff(day, last_logout_time, NOW()) <= 5 /* LIMIT 100 appended */ LIMIT 100;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userdatada_srchbotpointranking;
-- +goose StatementEnd
