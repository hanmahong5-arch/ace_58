-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_pollanswerda_srchpollrsbyidanddate(
    p_poll_id varchar(10),
    p_start_date varchar(30),
    p_end_date varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	poll_id,char_id,user_id, account_id, account_name, class, race, world, xlocation, ylocation, zlocation, lev, answer, TO_CHAR(answer_time, 'YYYY-MM-DD HH24:MI:SS') answer_time from	poll_answer where	poll_id=p_poll_id and answer_time >= '' || p_start_date || '' and answer_time < '' || p_end_date || '';
END;
$$;
