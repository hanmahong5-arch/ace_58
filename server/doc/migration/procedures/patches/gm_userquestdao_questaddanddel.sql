-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userquestdao_questaddanddel(
    p_char_id integer,
    p_quest_id integer,
    p_quest_status integer,
    p_quest_progress integer,
    p_quest_branch integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT quest_id FROM user_quest  WHERE  char_id = p_char_id and quest_id = p_quest_id) THEN
    UPDATE user_quest SET quest_status = p_quest_status , quest_progress = p_quest_progress, quest_branch = p_quest_branch WHERE char_id = p_char_id and quest_id = p_quest_id;
    ELSE
    INSERT into user_quest(char_id, quest_id, quest_status, quest_progress, quest_branch) VALUES (p_char_id, p_quest_id, p_quest_status, p_quest_progress, p_quest_branch);
    END IF;
END;
$$;
