-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_guildda_srchguildwarehousehistory(
    p_guild_id integer,
    p_view_count integer,
    p_top_count integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM  id, guild_id, eventdate, eventtype, eventparam, eventparam2 from	guild_warehouse_history where	guild_id = p_guild_id and id not in (SELECT  id from guild_warehouse_history where guild_id = p_guild_id order by id desc LIMIT p_top_count) order by id desc LIMIT p_view_count;
END;
$$;
