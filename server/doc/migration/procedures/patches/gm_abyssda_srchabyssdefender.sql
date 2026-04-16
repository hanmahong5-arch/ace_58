-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssdefender(
    p_world_id varchar(5),
    p_abyss_id varchar(20),
    p_srch_type varchar(1),
    p_user_id varchar(30),
    p_view_count varchar(5),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(4000);
    v_sql_where varchar(200);
BEGIN
    v_sql_where := '';
    IF (p_user_id != 'null') THEN
    IF p_srch_type = '1' THEN
    v_sql_where := v_sql_where || ' and user_id = ''' || p_user_id || '''';
    ELSE
    v_sql_where := v_sql_where || ' and defender_rank = ''' || p_user_id || '''';
    END IF;
    END IF;
    v_sql := 'select top(' || p_view_count || ') ' || '		a.*,' || '		COALESCE(u.delete_type, 0) as delete_type, COALESCE(u.delete_complete_date, 0) as delete_complete_date, COALESCE(u.delete_date, 0) as delete_date, COALESCE(u.char_id, a.defender_char_id) as char_id, COALESCE(u.user_id, 0) as user_id,' || '		COALESCE(u.account_id, 0) as account_id, COALESCE(u.account_name, 0) as account_name, COALESCE(u.org_server, a.defender_server_id) as org_server, COALESCE(u.cur_server, 0) as cur_server,' || '		COALESCE(u.org_server, 0) as login_server, TO_CHAR(COALESCE(u.create_date, ''1970-01-01''), ''YYYY-MM-DD HH24:MI:SS'') as create_date,' || '		CAST(COALESCE(u.gender, 0) AS char) as gender, CAST(COALESCE(u.race, 0) AS char) as race, CAST(COALESCE(u.class, 0) AS char) as class,' || '		CAST(COALESCE(u.lev, 0) AS char) as lev, CAST(COALESCE(u.builder, 0) AS char) as builder, COALESCE(u.world, 0) as world,' || '		case ' || '			WHEN u.last_login_time = u.last_logout_time and u.last_login_time != ''1970-01-01 00:00:00.000'' and u.last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' || '			WHEN u.last_login_time != u.last_logout_time or u.last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' || '			WHEN u.last_login_time = u.last_logout_time and u.last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' || '			ELSE ''silver'' ' || '		end as logonoff ' || ' from abyss_user_defender a ' || ' left join user_data u on a.defender_char_id=u.char_id and u.delete_type != ''10000'' and u.org_server=' || CAST(p_world_id AS varchar) || ' where	abyss_id=''' || p_abyss_id || ''' ' || ' and	defender_char_id^update_time not in (' || '	select top(' || p_top_count || ') defender_char_id^update_time ' || '	from abyss_user_defender a2 ' || '	left join user_data u2 on a2.defender_char_id=u2.char_id and u2.delete_type != ''10000'' and u2.org_server=' || CAST(p_world_id AS varchar) || '	where	abyss_id=''' || p_abyss_id || ''' ' || v_sql_where || '	order by a2.update_time desc, defender_rank, defender_siegepoint)';
    v_sql := v_sql || v_sql_where;
    v_sql := v_sql || ' order by a.update_time desc, defender_rank, defender_siegepoint';
    EXECUTE v_sql;
END;
$$;
