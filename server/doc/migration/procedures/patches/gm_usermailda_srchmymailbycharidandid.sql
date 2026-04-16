-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usermailda_srchmymailbycharidandid(
    p_char_id integer,
    p_mail_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	COALESCE(t2.name_id, 0) name_id, t1.id, t1.to_id, t1.to_name, t1.from_id, t1.from_name, t1.content, t1.title, t1.item_id, t1.item_nameid, t1.item_amount, t1.money, t1.state, t1.arrive_time, t1.express_mail, t1.abyss_point from	user_mail t1 left outer join user_item t2 on t1.item_id=t2.id where	(t1.id = p_mail_id) and (t1.from_id = p_char_id or  t1.to_id = p_char_id );
END;
$$;
