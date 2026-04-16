-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usertitledao_addorupdate(
    p_char_id integer,
    p_title_id varchar(20),
    p_is_have integer,
    p_expired_time integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT char_id FROM user_title  WHERE char_id = p_char_id and title_id=p_title_id) THEN
    UPDATE user_title SET is_have = p_is_have , expired_time = p_expired_time WHERE char_id = p_char_id and title_id=p_title_id;
    ELSE
    INSERT into user_title(char_id, title_id, is_have, expired_time) VALUES (p_char_id, p_title_id, p_is_have, p_expired_time);
    END IF;
END;
$$;
