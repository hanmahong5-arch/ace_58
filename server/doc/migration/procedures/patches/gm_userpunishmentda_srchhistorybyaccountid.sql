-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchhistorybyaccountid(
    p_account_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	login_id, login_nm, id, p.account_id, p.char_id, play_block, status, punish_code, TO_CHAR(start_date, 'YYYY-MM-DD HH24:MI:SS') start_date, TO_CHAR(end_date, 'YYYY-MM-DD HH24:MI:SS') end_date, TO_CHAR(cancel_date, 'YYYY-MM-DD HH24:MI:SS') cancel_date, (EXTRACT(EPOCH FROM (end_date)::timestamp - (CURRENT_TIMESTAMP)::timestamp) / 60)::integer left_min, cancel_reason, remain_minute, (EXTRACT(EPOCH FROM (end_date)::timestamp - (start_date)::timestamp) / 60)::integer st_end_diffdate, punish_reason , u.user_id from user_punishment p join user_data u on u.char_id = p.char_id where p.account_id = p_account_id order by status asc, start_date desc;
END;
$$;
