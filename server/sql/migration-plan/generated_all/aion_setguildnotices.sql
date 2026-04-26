-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetGuildNotices.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setguildnotices(_guild_id INTEGER, _notice_time1 INTEGER, _notice1 TEXT, _notice_time2 INTEGER, _notice2 TEXT, _notice_time3 INTEGER, _notice3 TEXT, _notice_time4 INTEGER, _notice4 TEXT, _notice_time5 INTEGER, _notice5 TEXT, _notice_time6 INTEGER, _notice6 TEXT, _notice_time7 INTEGER, _notice7 TEXT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
UPDATE guild 

SET noticetime1 = _notice_time1, notice1 = _notice1,

		noticetime2 = _notice_time2, notice2 = _notice2,

		noticetime3 = _notice_time3, notice3 = _notice3,

		noticetime4 = _notice_time4, notice4 = _notice4,

		noticetime5 = _notice_time5, notice5 = _notice5,

		noticetime6 = _notice_time6, notice6 = _notice6,

		noticetime7 = _notice_time7, notice7 = _notice7		

WHERE id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setguildnotices;
-- +goose StatementEnd
