-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_UpdateAbyssUserDefenderInfo_20110511.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_updateabyssuserdefenderinfo_20110511(_abyss_id INTEGER, _update_time INTEGER, _defender_char_id INTEGER, _defender_server_id INTEGER, _share_amount BIGINT, _defender_rank INTEGER, _siege_point INTEGER, _group_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
Insert abyss_user_defender (abyss_id, defender_char_id, defender_share_amount, defender_rank, update_time, defender_siegepoint, group_id, defender_server_id) 

VALUES (_abyss_id, _defender_char_id, _share_amount, _defender_rank, _update_time, _siege_point, _group_id, _defender_server_id);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_updateabyssuserdefenderinfo_20110511;
-- +goose StatementEnd
