-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userdatada_srchcharbyaccountidandstatus(
    p_account_id integer,
    p_world_id integer,
    p_include_normal smallint,
    p_include_delete smallint,
    p_include_delete_completed smallint
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
DECLARE
    v_query varchar(1000);
    v_where_or varchar(255);
BEGIN
    v_query := ';
    RETURN QUERY SELECT	char_id, USER_ID, account_id, account_name, race, class, gender , org_server, cur_server, world, builder, lev , create_date, last_login_time, last_logout_time , delete_date, delete_complete_date, delete_type, login_server from	user_data  where	account_id = ' || CAST(p_account_id AS varchar) || ' and		org_server = ' || CAST(p_world_id AS varchar);
    v_where_or := '1 != 1';
    IF (p_include_normal <> 0) THEN
    v_where_or := v_where_or || ' or (delete_date = 0 and delete_complete_date = 0)';
    END IF;
    IF (p_include_delete <> 0) THEN
    v_where_or := v_where_or || ' or (delete_date != 0 and delete_complete_date = 0)';
    END IF;
    IF (p_include_delete_completed <> 0) THEN
    v_where_or := v_where_or || ' or (delete_complete_date != 0)';
    END IF;
    v_where_or := ' and		(' || v_where_or || ')';
    v_query := v_query || v_where_or;
    EXECUTE v_query;
END;
$$;
