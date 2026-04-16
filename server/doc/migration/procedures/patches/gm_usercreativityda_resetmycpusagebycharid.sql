-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usercreativityda_resetmycpusagebycharid(
    p_char_id integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE	user_use_cp SET		value = 0, accumulated_cp = 0, data_id = 0 WHERE	char_id = p_char_id;
END;
$$;
