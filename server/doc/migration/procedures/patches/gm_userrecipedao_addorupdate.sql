-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userrecipedao_addorupdate(
    p_char_id integer,
    p_recipe_id varchar(20)
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF not EXISTS (SELECT char_id FROM user_recipe WHERE char_id = p_char_id and recipe_id=p_recipe_id) THEN
    INSERT into user_recipe(char_id, recipe_id) VALUES (p_char_id, p_recipe_id);
    END IF;
END;
$$;
