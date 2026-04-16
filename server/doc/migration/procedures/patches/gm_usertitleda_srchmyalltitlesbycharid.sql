-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usertitleda_srchmyalltitlesbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	char_id, title_id, is_have, expired_time from	user_title where	char_id = p_char_id;
END;
$$;
