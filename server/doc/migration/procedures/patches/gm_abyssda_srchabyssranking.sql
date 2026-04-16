-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_abyssda_srchabyssranking(
    p_char_id integer,
    p_update_time integer DEFAULT 0
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_update_time integer;
BEGIN
    SELECT max(update_time) INTO v_last_update_time FROM abyss_ranking;
    RETURN QUERY SELECT abyss_ranking, abyss_point, update_time, rank, rank_updatedate, gp from abyss_ranking  where char_id = p_char_id and update_time = v_last_update_time;
END;
$$;
