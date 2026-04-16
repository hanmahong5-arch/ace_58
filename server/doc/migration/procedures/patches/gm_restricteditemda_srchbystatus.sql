-- database: aion_world_live
CREATE OR REPLACE FUNCTION gm_restricteditemda_srchbystatus(
    p_restrict_status varchar(4)
) RETURNS SETOF record
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY SELECT	TO_CHAR(regdate, 'YYYY-MM-DD HH24:MI:SS') regdate,TO_CHAR(START_DATE, 'YYYY-MM-DD HH24:MI:SS') START_DATE,TO_CHAR(end_date, 'YYYY-MM-DD HH24:MI:SS') end_date,id,RESTRICTED_ID,WORLD_ID,SERVICE_TYPE,TYPE,ITEM_NAME_ID,VALUE,RESTRICT_STATUS,LOGIN_ID,LOGIN_NM,UP_INFO,SERVICE_CLASS_TYPE from	restricted_item  where	restrict_status=p_restrict_status;
END;
$$;
