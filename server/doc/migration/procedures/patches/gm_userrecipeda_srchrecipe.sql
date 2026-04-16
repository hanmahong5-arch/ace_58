-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userrecipeda_srchrecipe(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT recipe_id, remain_count from user_recipe  where char_id = p_char_id;
END;
$$;
