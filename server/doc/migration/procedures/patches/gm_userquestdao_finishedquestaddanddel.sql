-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userquestdao_finishedquestaddanddel(
    p_char_id integer,
    p_quest_id integer,
    p_quest_count integer,
    p_quest_branch integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT quest_id FROM user_finished_quest  WHERE  char_id = p_char_id and quest_id = p_quest_id) THEN
    UPDATE user_finished_quest SET quest_count = p_quest_count , quest_branch = p_quest_branch WHERE char_id = p_char_id and quest_id = p_quest_id;
    ELSE
    INSERT into user_finished_quest(char_id, quest_id, quest_count, quest_branch) VALUES (p_char_id, p_quest_id, p_quest_count, p_quest_branch);
    END IF;
END;
$$;
