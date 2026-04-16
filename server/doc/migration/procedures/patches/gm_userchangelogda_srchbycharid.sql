-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userchangelogda_srchbycharid(
    p_char_id integer,
    p_change_type varchar(2)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	* from	user_change_log where	char_id = p_char_id::integer and change_type=p_change_type || '' order by change_time desc;
END;
$$;
