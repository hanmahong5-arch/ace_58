-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_abyssda_srchcharabysscontributor(
    p_char_id varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  abyss_id, owner_share_amount, owner_rank, update_time from abyss_user_owner  where owner_char_id=p_char_id order by update_time desc LIMIT 300;
END;
$$;
