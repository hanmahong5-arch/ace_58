-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_useritemda_srchmypolisheditemsforcopy(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT t2.id, t2.name_id, t2.random_id, t2.polish_point from user_item t1, user_item_polish t2 where t1.char_id = p_char_id and t1.id=t2.id and t1.warehouse!=10 and t1.warehouse!=11 and t1.warehouse!=17 and t1.warehouse!=18 and t1.warehouse!=19 and t1.warehouse!=20;
END;
$$;
