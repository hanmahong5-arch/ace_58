-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userdatada_srchabuseqina(
    p_world_id varchar(5),
    p_user_id varchar(30),
    p_account_name varchar(50),
    p_bx_char_id varchar(25),
    p_view_count varchar(5),
    p_top_count varchar(5)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(4000);
    v_tmp integer;
    v_sql_etc varchar(1000);
BEGIN
    v_sql_etc := ' and delete_type != ''10000'' ';
    IF p_user_id != 'null' THEN
    v_sql_etc := v_sql_etc || ' and user_id = ''' || p_user_id || '''';
    END IF;
    IF p_bx_char_id != 'null' THEN
    v_sql_etc := v_sql_etc || ' and char_id = ''' || p_bx_char_id || '''';
    END IF;
    IF p_account_name != 'null' THEN
    v_sql_etc := v_sql_etc || ' AND account_name = ''' || p_account_name || '''';
    END IF;
    v_sql := 'select top ' || p_view_count || ' 	delete_type, delete_complete_date, inventory_growth, char_warehouse_growth, delete_date, char_id, user_id, account_id, account_name, org_server, cur_server,COALESCE(login_server, org_server) login_server,' || ' 	TO_CHAR(create_date, ''YYYY-MM-DD HH24:MI:SS'') create_date, CAST(gender AS char) gender, CAST(race AS char) race, CAST(class AS char) class, CAST(lev AS char) lev, CAST(builder AS char) builder, exp, world,	' || '   case ' || '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' and last_logout_time > ''2007-12-12 00:00:00.000'' THEN ''#339900'' ' || '     WHEN last_login_time != last_logout_time or last_login_time = ''1970-01-01 00:00:00.000''  THEN ''brown'' ' || '     WHEN last_login_time = last_logout_time and last_login_time != ''1970-01-01 00:00:00.000'' THEN ''black'' ' || '   end as logonoff, t2.* ' || ' from user_data t1, qina_manipulate t2' || ' where t1.char_id=t2.charid and t2.qina_id not in(select top ' || p_top_count || ' t2.qina_id from user_data t1, qina_manipulate t2 where t1.char_id=t2.charid and org_server=''' || p_world_id || ''' ' || v_sql_etc || '  order by t2.qina_id desc) ';
    v_sql := v_sql || v_sql_etc;
    v_sql := v_sql || ' and org_server = ''' || p_world_id || '''';
    v_sql := v_sql || ' order by t2.qina_id desc ';
    EXECUTE v_sql;
END;
$$;
