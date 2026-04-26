-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_ClientSettingsPut.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_clientsettingsput(_char_id INTEGER, _data_size INTEGER, _data BYTEA)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
if exists (select char_id from user_client_settings(UPDLOCK) where char_id = _char_id) 

	begin

		update user_client_settings set data_size = _data_size, data = _data where char_id = _char_id

	end

else 

	begin

		insert user_client_settings(char_id, data_size, data) values (_char_id, _data_size, _data)

	end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_clientsettingsput;
-- +goose StatementEnd
