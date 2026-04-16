-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_houseda_srchallhouselist(
    p_race varchar(300),
    p_size varchar(300),
    p_state varchar(300),
    p_user_id varchar(20),
    p_account_name varchar(30),
    p_obj_id varchar(20)
) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_sql varchar(3000);
BEGIN
    v_sql := 'select t2.user_id, COALESCE(t2.org_server,0) as org_server,' || 't1.*, ' || 't3.id as auction_id, t3.race, t3.sellerid, t3.sellername, t3.buyerid, t3.buyername, t3.qina, t3.stepqina, t3.createtime, t3.betCount, t3.lastupdate,' || 't4.land_nameid, t4.world_id, t4.center_x, t4.center_y, t4.center_z ' || 'from house_field t1 left outer join user_data t2 on t1.owner_id=t2.char_id ' || 'left outer join user_auction t3 on t1.addr_id=t3.goodsid and (t3.state=0 or t3.state=1)' || ' join house_addrinfo t4 on t1.addr_id=t4.addr_id ' || 'left outer join user_auctionfilter t5 on t1.addr_id=t5.goodsID ' || 'where t5.goodsID is null ';
    IF p_race != '' THEN
    v_sql := v_sql || 'and ' || p_race;
    END IF;
    IF p_size != '' THEN
    v_sql := v_sql || 'and ' || p_size;
    END IF;
    IF p_state = '(t1.state=6)' THEN
    v_sql := v_sql || 'and t1.chargeCount <= 0';
    ELSE
    IF p_state != '' THEN
    v_sql := v_sql || 'and ' || p_state;
    END IF;
    END IF;
    IF p_user_id is not null THEN
    v_sql := v_sql || ' and t2.user_id=''' || p_user_id || ''' ';
    END IF;
    IF p_account_name is not null THEN
    v_sql := v_sql || ' and t2.account_name=''' || p_account_name || ''' ';
    END IF;
    IF p_obj_id != '0' THEN
    v_sql := v_sql || ' and t1.addr_id=' || p_obj_id;
    END IF;
    RAISE NOTICE '%', v_sql;
    EXECUTE v_sql;
END;
$$;
