-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_guildda_srchguildapplicationscount(
    p_guild_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT count(*) guild_application_cnt from user_guild_join_application t1 where t1.guild_id = p_guild_id;
END;
$$;
