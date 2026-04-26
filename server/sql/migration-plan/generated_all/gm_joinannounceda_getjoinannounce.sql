-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_JoinAnnounceDA_GetJoinAnnounce.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_joinannounceda_getjoinannounce(_world_id TEXT, _notice_status TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			SELECT notice_id, notice_status, LOGIN_ID, LOGIN_NM, NOTICE_INTRO, NOTICE_ETC, NOTICE_SENTENCE_HEADER,	NOTICE_SENTENCE1,	NOTICE_SENTENCE2,	NOTICE_SENTENCE3,	NOTICE_SENTENCE4,	NOTICE_SENTENCE5,	NOTICE_SENTENCE6,	NOTICE_SENTENCE7,	NOTICE_SENTENCE8, NOTICE_SENTENCE9, NOTICE_SENTENCE10, WORLD_ID, NOTICE_POS_TYPE, regdate

			from	join_announce(nolock)

			where	world_id=_world_id and notice_status=''+_notice_status+'' /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_joinannounceda_getjoinannounce;
-- +goose StatementEnd
