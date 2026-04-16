-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_bookmarkda_srchbookmarkbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT bookmark_id, char_id, bookmark, world, x, y, z from bookmark where char_id = p_char_id order by bookmark_id asc;
END;
$$;
