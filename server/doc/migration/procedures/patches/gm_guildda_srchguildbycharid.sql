-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_guildda_srchguildbycharid(
    p_char_id integer
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	u.class, u.user_id, u.account_id, u.account_name, u.org_server , g.name, g.id, g.master_id FROM	user_data u JOIN	guild g ON g.master_id = u.char_id and g.id = u.guild_id WHERE	g.id = (select guild_id from user_data where char_id = p_char_id);
    RETURN;
END;
$$;
