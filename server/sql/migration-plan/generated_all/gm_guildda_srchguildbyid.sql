-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_GuildDA_SrchGuildByID.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_guildda_srchguildbyid(_guild_id TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			set ansi_warnings off	

			

			SELECT	g.level, g.officer_right, g.member_right, g.id, g.name, g.master_id, g.rank, g.point, g.fund, g.delete_requested, g.delete_time

					, g.notice1, g.notice2, g.notice3, g.notice4, g.notice5, g.notice6, g.notice7

					, g.noticetime1, g.noticetime2, g.noticetime3, g.noticetime4, g.noticetime5, g.noticetime6, g.noticetime7

					, COALESCE(u.user_id, 0) as user_id, COALESCE(u.account_id, 0) as account_id, COALESCE(u.account_name, '') as account_name, COALESCE(u.race, 0) as race

					, g.point_max_time

					-- [4.9] 길드 자동 가입 관련

					, g.intro, g.join_process_type, g.join_restrict_level

			FROM	guild g(nolock)

			LEFT JOIN	user_data u(nolock) ON g.master_id = u.char_id and g.id = u.guild_id

			WHERE	g.id = _guild_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_guildda_srchguildbyid;
-- +goose StatementEnd
