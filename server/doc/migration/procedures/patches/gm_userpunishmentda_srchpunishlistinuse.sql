-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchpunishlistinuse(
    p_account_id integer,
    p_char_id integer,
    p_status varchar(2)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	login_id, login_nm, id, account_id, char_id, play_block, status, punish_code, TO_CHAR(start_date, 'YYYY-MM-DD HH24:MI:SS') start_date, TO_CHAR(end_date, 'YYYY-MM-DD HH24:MI:SS') end_date, TO_CHAR(cancel_date, 'YYYY-MM-DD HH24:MI:SS') cancel_date, (EXTRACT(EPOCH FROM (end_date)::timestamp - (CURRENT_TIMESTAMP)::timestamp) / 60)::integer left_min, cancel_reason, remain_minute, (EXTRACT(EPOCH FROM (end_date)::timestamp - (start_date)::timestamp) / 60)::integer st_end_diffdate, punish_reason from	user_punishment where	account_id = p_account_id and char_id = p_char_id and status='' || p_status || '' order by punish_code asc;
END;
$$;
