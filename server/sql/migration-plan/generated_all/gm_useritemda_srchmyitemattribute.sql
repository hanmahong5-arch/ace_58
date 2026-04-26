-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchMyItemAttribute.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchmyitemattribute(_char_id INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			select	a.id, a.attribute1, a.attribute1value, a.attribute2, a.attribute2value, a.attribute3, a.attribute3value, a.attribute4, a.attribute4value, a.attribute5, a.attribute5value, a.attribute6, a.attribute6value

			from	user_item i(nolock)

			join	user_item_attribute  a (nolock) on a.id = i.id

			where	i.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchmyitemattribute;
-- +goose StatementEnd
