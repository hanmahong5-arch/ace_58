-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_usermailda_srchmymailitemmoney(
    p_char_id integer,
    p_item_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	id, to_id, to_name, from_id, from_name, title, content, item_id, item_nameid, item_amount, money, state, arrive_time, express_mail, item_tid from	user_mail  where	to_id = p_char_id and item_id = p_item_id;
END;
$$;
