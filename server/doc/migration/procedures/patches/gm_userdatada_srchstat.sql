-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userdatada_srchstat(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	* from	user_stat  where	character_id = p_char_id;
END;
$$;
