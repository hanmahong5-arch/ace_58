-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateAbyssUserOwnerInfo_20110511.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updateabyssuserownerinfo_20110511(_abyss_id INTEGER, _update_time INTEGER, _owner_char_id INTEGER, _owner_server_id INTEGER, _share_amount BIGINT, _owner_rank INTEGER, _siege_point INTEGER, _group_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
Insert abyss_user_owner (abyss_id, owner_char_id, owner_share_amount, owner_rank, update_time, owner_siegepoint, group_id, owner_server_id) 

VALUES (_abyss_id, _owner_char_id, _share_amount, _owner_rank, _update_time, _siege_point, _group_id, _owner_server_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updateabyssuserownerinfo_20110511;
-- +goose StatementEnd
