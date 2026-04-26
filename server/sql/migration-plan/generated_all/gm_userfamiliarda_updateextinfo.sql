-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserFamiliarDA_UpdateExtInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_userfamiliarda_updateextinfo(_char_id INTEGER, _familiar_func_expire_time BIGINT, _familiar_energy BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

UPDATE user_data_ext

SET familiar_func_expireTime=_familiar_func_expire_time, familiar_energy=_familiar_energy

WHERE char_id = _char_id

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_userfamiliarda_updateextinfo;
-- +goose StatementEnd
