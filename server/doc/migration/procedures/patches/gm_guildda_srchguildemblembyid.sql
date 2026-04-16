-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_guildda_srchguildemblembyid(
    p_guild_id varchar(10)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT emblem,emblem_img,emblem_img_version,emblem_img_last_version,emblem_bgcolor from guild where id=p_guild_id;
END;
$$;
