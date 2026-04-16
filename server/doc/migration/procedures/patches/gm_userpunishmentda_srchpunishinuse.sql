-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchpunishinuse(
    p_account_id integer,
    p_char_id integer,
    p_status varchar(2),
    p_punish_code varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  id from	user_punishment where	account_id = p_account_id and char_id = p_char_id and status='' || p_status || '' and punish_code='' || p_punish_code || '' order by id desc LIMIT 1;
END;
$$;
