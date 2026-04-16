-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usermacroda_srchmacrolist(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	char_id, slot_id, data from	user_macro  where	char_id = p_char_id;
END;
$$;
