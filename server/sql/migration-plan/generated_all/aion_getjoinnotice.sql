-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetJoinNotice.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getjoinnotice()
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
SELECT

	LOGIN_ID,

	LOGIN_NM,

	NOTICE_INTRO, 

	NOTICE_ETC,

	NOTICE_SENTENCE_HEADER,

	NOTICE_SENTENCE1,

	NOTICE_SENTENCE2,

	NOTICE_SENTENCE3,

	NOTICE_SENTENCE4,

	NOTICE_SENTENCE5,

	NOTICE_SENTENCE6,

	NOTICE_SENTENCE7,

	NOTICE_SENTENCE8,

	NOTICE_SENTENCE9,

	NOTICE_SENTENCE10,

	WORLD_ID,

	NOTICE_POS_TYPE

FROM 

	JOIN_ANNOUNCE

WHERE

	NOTICE_STATUS = 'Y';
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getjoinnotice;
-- +goose StatementEnd
