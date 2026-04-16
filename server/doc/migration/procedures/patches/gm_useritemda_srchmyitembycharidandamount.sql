-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyitembycharidandamount(
    p_char_id integer,
    p_amount integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT id from user_item where char_id = p_char_id and amount <= p_amount and warehouse=50;
END;
$$;
