-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_AddCharRankPoint.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_AddCharRankPoint.sql
-- Increments rank_point (Abyss) on PvE / PvP rewards.
-- TODO B4 — verify exact NCSoft column (could be abyss_point_from_user instead
-- of rank_point); current scaffold only carries rank_point. Reviewed: rank_point
-- is the additive 'this-week' bucket in NCSoft schema, separate from total
-- abyss_point. Safe choice for now.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addcharrankpoint(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_addcharrankpoint(_char_id INTEGER, _delta INTEGER)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    _new BIGINT;
BEGIN
    UPDATE user_data
       SET rank_point = rank_point + _delta,
           change_info_time = GetUnixtimeWithUTCAdjust(NOW() AT TIME ZONE 'UTC', 0)
     WHERE char_id = _char_id
    RETURNING rank_point INTO _new;
    RETURN COALESCE(_new, 0);
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_addcharrankpoint(INTEGER, INTEGER);
-- +goose StatementEnd
