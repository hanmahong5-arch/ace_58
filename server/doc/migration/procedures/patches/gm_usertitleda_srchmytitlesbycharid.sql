-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usertitleda_srchmytitlesbycharid(
    p_char_id integer,
    p_is_have varchar(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	title_id, expired_time from	user_title where	char_id = p_char_id and is_have=p_is_have order by title_id asc;
END;
$$;
