-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_guildda_srchguildmemberscount(
    p_guild_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT count(*) guild_member_cnt from user_data t1 where t1.guild_id = p_guild_id;
END;
$$;
