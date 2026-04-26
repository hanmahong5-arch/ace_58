-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildEmblem.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildemblem(_guild_id INTEGER, _version INTEGER, _last_version INTEGER, _bg_color INTEGER, _emblem BYTEA)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild set emblem_img_version=_version, emblem_img_last_version=_last_version, emblem_bgcolor=_bg_color, emblem_img=_emblem where id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildemblem;
-- +goose StatementEnd
