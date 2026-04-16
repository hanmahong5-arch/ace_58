-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_useritemda_srchsealeditems(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	id, sealExpiredTime, sealState from	user_item_sealed  where	char_id = p_char_id;
END;
$$;
