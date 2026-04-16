-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_userdatada_srchitemranking(
    p_item_id varchar(30)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT  sum(t1.amount) amount,t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.race, t2.class, t2.gender, t2.lev from	user_item t1, user_data t2 where	t1.char_id = t2.char_id and		t1.name_id=p_item_id group by t2.char_id, t2.user_id, t2.account_id, t2.account_name, t2.race, t2.class, t2.gender, t2.lev order by amount desc LIMIT 100;
END;
$$;
