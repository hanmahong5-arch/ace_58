-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usercommentda_srchmymemolistbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	* from	user_comment where	char_id = p_char_id order by comment_id desc;
END;
$$;
