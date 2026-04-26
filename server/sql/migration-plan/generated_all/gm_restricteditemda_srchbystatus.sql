-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_RestrictedItemDA_SrchByStatus.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_restricteditemda_srchbystatus(_restrict_status TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off

			

			select	convert(nvarchar,regdate,20) regdate,convert(nvarchar,START_DATE,20) START_DATE,convert(nvarchar,end_date,20) end_date,id,RESTRICTED_ID,WORLD_ID,SERVICE_TYPE,TYPE,ITEM_NAME_ID,VALUE,RESTRICT_STATUS,LOGIN_ID,LOGIN_NM,UP_INFO,SERVICE_CLASS_TYPE

			from	restricted_item (nolock)

			where	restrict_status=_restrict_status;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_restricteditemda_srchbystatus;
-- +goose StatementEnd
