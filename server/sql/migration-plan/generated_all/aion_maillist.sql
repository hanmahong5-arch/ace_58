-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_MailList.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_maillist(_char_id INTEGER, _now_time INTEGER, _mail INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
--[2010/01/05 spinel]

--select id, from_name, title, state, arrive_time, item_id, money, express_mail 

--from user_mail (nolock)

--where to_id = _char_id and arrive_time <= _now_time 

--order by arrive_time desc



/*

SELECT id, from_name, title, state, arrive_time, item_id, money, express_mail

FROM user_mail (nolock) WHERE id IN

(

SELECT id

FROM user_mail (nolock)

WHERE to_id = _char_id and arrive_time <= _now_time 

ORDER BY arrive_time

)

ORDER BY arrive_time desc

*/



SELECT top (_mail) id, from_name, title, state, arrive_time, item_id, money, abyss_point, express_mail

FROM user_mail (nolock)

WHERE to_id =  _char_id and arrive_time <= _now_time  

ORDER BY arrive_time desc


 /* LIMIT 100 appended */ LIMIT 100;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_maillist;
-- +goose StatementEnd
