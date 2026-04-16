-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usermoveservicelogda_srchmovedcharinfo(
    p_server_id_from varchar(5),
    p_char_id_from varchar(20)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  * from user_move_service_log where server_id_from=p_server_id_from and char_id_from=p_char_id_from order by id desc LIMIT 1;
    RETURN;
END;
$$;
