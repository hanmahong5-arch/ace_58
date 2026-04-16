-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyitembycharidanditemid(
    p_char_id integer,
    p_item_id varchar(30),
    p_item_deposit integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT id, amount from user_item where char_id = p_char_id and name_id=p_item_id and warehouse = p_item_deposit;
    RETURN;
END;
$$;
