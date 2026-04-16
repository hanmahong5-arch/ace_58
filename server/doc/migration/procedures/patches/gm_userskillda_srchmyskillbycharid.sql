-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userskillda_srchmyskillbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	char_id, skill_id, skill_data1, skill_data2 from	user_skill where	char_id = p_char_id;
END;
$$;
