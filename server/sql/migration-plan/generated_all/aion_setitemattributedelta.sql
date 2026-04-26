-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemAttributeDelta.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemattributedelta(_id BIGINT, _attr1 INTEGER, _attr1value INTEGER, _attr2 INTEGER, _attr2value INTEGER, _attr3 INTEGER, _attr3value INTEGER, _attr4 INTEGER, _attr4value INTEGER, _attr5 INTEGER, _attr5value INTEGER, _attr6 INTEGER, _attr6value INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from

	-- interfering with SELECT statements.


	

	Update user_item_attribute set 

		Attribute1 = _attr1, Attribute1Value =_attr1value,

		Attribute2 = _attr2, Attribute2Value =_attr2value,

		Attribute3 = _attr3, Attribute3Value =_attr3value,

		Attribute4 = _attr4, Attribute4Value =_attr4value,

		Attribute5 = _attr5, Attribute5Value =_attr5value,

		Attribute6 = _attr6, Attribute6Value =_attr6value

	where ID = _id 

	

	if @_r_o_w_c_o_u_n_t = 0

	begin

		insert into user_item_attribute (id, Attribute1, Attribute1Value, Attribute2, Attribute2Value, Attribute3, Attribute3Value,

											 Attribute4, Attribute4Value, Attribute5, Attribute5Value, Attribute6, Attribute6Value)

								values  (_id, _attr1, _attr1value, _attr2, _attr2value, _attr3, _attr3value,

											 _attr4, _attr4value, _attr5, _attr5value, _attr6, _attr6value)

	end

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemattributedelta;
-- +goose StatementEnd
