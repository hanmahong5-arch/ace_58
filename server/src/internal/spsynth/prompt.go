package spsynth

import (
	"fmt"
	"strings"
)

// TsqlToPlpgsqlPrompt 根据 T-SQL 存储过程文本和 schema 上下文，
// 构建结构化多段 LLM prompt，按 system/role/style/schema-context/
// conversion-rules/few-shots/output-format 七段组织。
// 使用 Go 1.21+ 文本块风格（raw string literals）保持可读性。
func TsqlToPlpgsqlPrompt(tsql string, schema SchemaContext) string {
	var b strings.Builder

	// ── 第 1 段：System 角色定义 ──────────────────────────────────────────
	b.WriteString(`=== SYSTEM ===
你是一名精通 SQL Server T-SQL 与 PostgreSQL PL/pgSQL 的数据库移植专家，
专注于将 NCSoft AION 5.8 游戏服务器的 T-SQL 存储过程机械、精确地转换为 PL/pgSQL。
`)

	// ── 第 2 段：Role 职责 ────────────────────────────────────────────────
	b.WriteString(`
=== ROLE ===
- 输入：一个 T-SQL CREATE PROCEDURE 文本（来自 SQL Server 2019）
- 输出：等价的 PostgreSQL 16+ PL/pgSQL CREATE OR REPLACE FUNCTION 文本
- 保证语义等价：相同输入 → 相同结果集（行数、列顺序、数据类型）
- 不添加任何业务逻辑，不优化查询，严格 1:1 映射
`)

	// ── 第 3 段：Style 规范 ───────────────────────────────────────────────
	b.WriteString(`
=== STYLE ===
- 所有 PostgreSQL 标识符（表名、列名）必须用双引号包裹，例如 "guild"、"name"
- 函数签名使用 CREATE OR REPLACE FUNCTION schema.func_name(params) RETURNS ...
- 函数体使用 $$ ... $$ LANGUAGE plpgsql
- 使用 RETURNS TABLE(...) 或 RETURNS SETOF record 返回多行结果
- 返回单标量值使用 RETURNS <type>，函数体末尾 RETURN (SELECT ...)
- 严禁在函数体内写裸 DML（INSERT/UPDATE/DELETE 须包装在 BEGIN...END 或通过 SP 调用）
`)

	// ── 第 4 段：Schema Context ───────────────────────────────────────────
	b.WriteString("\n=== SCHEMA CONTEXT ===\n")
	if len(schema.Tables) > 0 {
		b.WriteString("已知表结构：\n")
		for _, t := range schema.Tables {
			b.WriteString(fmt.Sprintf(
				"  TABLE %s  PK=%s  COLUMNS=[%s]\n",
				t.Name, t.PrimaryKey, strings.Join(t.Columns, ", "),
			))
		}
	} else {
		b.WriteString("（未提供表结构，根据 T-SQL 文本中引用的表名推断）\n")
	}

	// ── 第 5 段：Conversion Rules ─────────────────────────────────────────
	b.WriteString(`
=== CONVERSION RULES ===
1. @param int          → p_param INTEGER（去掉 @ 前缀，加 p_ 前缀）
2. @param nvarchar(N)  → p_param VARCHAR(N)
3. SET NOCOUNT ON/OFF  → 删除（PG 不需要）
4. SELECT TOP N        → 后追加 LIMIT N
5. ISNULL(x, y)        → COALESCE(x, y)
6. [dbo].[table]       → "table"（去掉 schema 前缀，加双引号）
7. CREATE PROC/PROCEDURE → CREATE OR REPLACE FUNCTION
8. #tmp_table（临时表）   → CREATE TEMP TABLE tmp_table（在函数体内）
9. @@ROWCOUNT           → GET DIAGNOSTICS affected = ROW_COUNT
10. TRY/CATCH           → BEGIN ... EXCEPTION WHEN OTHERS THEN ...
11. PRINT 'msg'         → RAISE NOTICE 'msg'
12. EXEC sp_name        → PERFORM sp_name() 或 SELECT * FROM sp_name()
`)

	// ── 第 6 段：Few-shots ────────────────────────────────────────────────
	b.WriteString(`
=== FEW-SHOTS ===
--- T-SQL 示例 ---
CREATE PROCEDURE [dbo].[aion_GetPlayerLevel]
    @charid int
AS
SELECT level FROM characters WHERE char_id = @charid

--- PL/pgSQL 等价 ---
CREATE OR REPLACE FUNCTION aion_world_live.aion_GetPlayerLevel(p_charid INTEGER)
RETURNS TABLE(level INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT c."level"
    FROM "characters" c
    WHERE c."char_id" = p_charid;
END;
$$;
`)

	// ── 第 7 段：Output Format ────────────────────────────────────────────
	b.WriteString(`
=== OUTPUT FORMAT ===
只输出 PL/pgSQL 函数文本，不加任何解释或 markdown 代码块。
第一行必须是 CREATE OR REPLACE FUNCTION ...
最后一行必须是 $$; 或类似合法结束符。
`)

	// ── 待转换的 T-SQL 输入 ───────────────────────────────────────────────
	b.WriteString("\n=== INPUT T-SQL ===\n")
	b.WriteString(tsql)
	b.WriteString("\n\n=== OUTPUT PL/pgSQL ===\n")

	return b.String()
}
