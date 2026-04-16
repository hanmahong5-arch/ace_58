-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usercreativityda_srchmyusecreativitybycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT category ,enchant_object_id ,value ,accumulated_cp ,data_id FROM user_use_cp where	char_id = p_char_id;
END;
$$;
