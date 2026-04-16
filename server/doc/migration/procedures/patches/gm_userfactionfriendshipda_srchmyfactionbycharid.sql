-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userfactionfriendshipda_srchmyfactionbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	char_id, faction_id, friendship, jointime, factionquest_curid, factionquest_curstate, factionquest_lastacquiredtime, factionquest_lastfinishedtime, factionquest_finishedcount from	user_faction_friendship where	char_id = p_char_id;
END;
$$;
