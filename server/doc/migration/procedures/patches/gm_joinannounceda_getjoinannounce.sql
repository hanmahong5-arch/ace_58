-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_joinannounceda_getjoinannounce(
    p_world_id integer,
    p_notice_status varchar(1)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  notice_id, notice_status, LOGIN_ID, LOGIN_NM, NOTICE_INTRO, NOTICE_ETC, NOTICE_SENTENCE_HEADER,	NOTICE_SENTENCE1,	NOTICE_SENTENCE2,	NOTICE_SENTENCE3,	NOTICE_SENTENCE4,	NOTICE_SENTENCE5,	NOTICE_SENTENCE6,	NOTICE_SENTENCE7,	NOTICE_SENTENCE8, NOTICE_SENTENCE9, NOTICE_SENTENCE10, WORLD_ID, NOTICE_POS_TYPE, regdate from	join_announce where	world_id = p_world_id and notice_status='' || p_notice_status || '' LIMIT 1;
END;
$$;
