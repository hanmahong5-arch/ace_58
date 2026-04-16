-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usercustomizehistoryda_srchmycustomizehistory(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	* from	user_customize_history  where	char_id = p_char_id order by history_date asc;
END;
$$;
