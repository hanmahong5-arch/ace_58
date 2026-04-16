-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usermoveservicelogda_srchmymovedcharlog(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from user_move_service_log where char_id = p_char_id order by id desc;
    RETURN;
END;
$$;
