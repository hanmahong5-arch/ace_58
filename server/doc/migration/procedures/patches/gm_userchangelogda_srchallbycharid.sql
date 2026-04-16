-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userchangelogda_srchallbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	TO_CHAR(change_time, 'YYYY-MM-DD HH24:MI:SS') change_time, char_id, change_type, race, class, lev, old_value, new_value, playtime, intervaltime from	user_change_log  where	char_id = p_char_id;
END;
$$;
