-- 来源：ACE_5.8/server/sql/synth/example_001_aion_GetGuildId.tsql
-- 原始 SP：AionWorldLive.dbo.aion_GetGuildId（T-SQL，12 行）
-- 转换方法：LLM Agentic Synthesis（spsynth 包 FakeLLMClient 原型）
-- 人工审核状态：[待审核] — 生成后需 DBA 确认等价性后方可归档至 sql/ 主目录
-- 等价性验证：shadow_compare + property_validator（见 internal/spsynth/）

-- PostgreSQL 16+ PL/pgSQL 等价实现
-- 函数名保留原始 SP 名称，schema 使用 aion_world_live
-- 入参 @strGuildName nvarchar(32) → p_str_guild_name VARCHAR(32)
-- SELECT id FROM guild → RETURNS TABLE(id INTEGER)，标识符加双引号

CREATE OR REPLACE FUNCTION aion_world_live.aion_GetGuildId(
    p_str_guild_name VARCHAR(32)  -- 公会名称，对应 T-SQL @strGuildName
)
RETURNS TABLE(id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    -- 原始 T-SQL: SELECT id FROM guild where name = @strGuildName
    -- SET NOCOUNT ON/OFF 在 PG 中不需要，直接删除
    RETURN QUERY
    SELECT g."id"
    FROM "guild" g
    WHERE g."name" = p_str_guild_name;
END;
$$;
