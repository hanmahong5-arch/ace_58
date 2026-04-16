-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userpunishmentda_srchcheck(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  ID from user_punishment  where char_id = p_char_id and status = 0 and ((play_block = 1 and end_date > CURRENT_TIMESTAMP) or (play_block = 0 and Remain_Minute > 0)) and (punish_code != 101 and punish_code != 102) LIMIT 1;
END;
$$;
