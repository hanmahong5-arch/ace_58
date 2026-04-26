-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_CheckHousingObjectCount.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_CheckHousingObjectCount.sql
--
-- Returns MAX(id) from houseobject. The original commented-out branch reads
-- sysindexes.rows; the active branch is MAX(id). We mirror the active branch.
-- A NULL is converted to 0 (safer for the caller).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkhousingobjectcount();
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_checkhousingobjectcount()
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    max_id BIGINT;
BEGIN
    SELECT COALESCE(MAX(id), 0) INTO max_id FROM houseobject;
    RETURN max_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_checkhousingobjectcount();
-- +goose StatementEnd
