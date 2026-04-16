-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_useritemda_srchvendorlog(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT * from vendor_log_light where char_id = p_char_id union all select * from vendor_log_dark where char_id = p_char_id;
END;
$$;
