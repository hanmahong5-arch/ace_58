-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_serverinfoda_srchserverinfobycond(
    p_server_id integer,
    p_info_name varchar(40)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	server_id, info_name, int_value, int64_value, str_value from	server_info  where	server_id = p_server_id and info_name='' || p_info_name || '';
END;
$$;
