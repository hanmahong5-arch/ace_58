package spsynth

import (
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ─────────────────────────────────────────────────────────────────────────────
// 测试辅助：staticQueryRunner 返回固定的行集，用于影子测试
// ─────────────────────────────────────────────────────────────────────────────

// staticQueryRunner 是 QueryRunner 的 mock 实现，每次 Run 返回预设的 rows。
type staticQueryRunner struct {
	rows [][]any
}

func (r *staticQueryRunner) Run(_ []any) ([][]any, error) {
	return r.rows, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// 测试 1：简单 SELECT 返回单值（Fake LLM 返回固定 plpgsql）
// ─────────────────────────────────────────────────────────────────────────────

// TestSynth_SimpleSelect 验证最基础的 SELECT 单值 SP 合成流程。
// Fake LLM 返回预设 PL/pgSQL，验证 SynthResult 包含正确的 PLpgSQL 文本。
func TestSynth_SimpleSelect(t *testing.T) {
	// 准备临时 T-SQL 文件
	dir := t.TempDir()
	tsqlPath := filepath.Join(dir, "aion_GetGuildId.sql")
	tsqlContent := `-- Source: AionWorldLive.dbo.aion_GetGuildId
CREATE proc [dbo].[aion_GetGuildId]
    @strGuildName nvarchar(32)
as
set nocount on
SELECT id FROM guild where name = @strGuildName
set nocount off
`
	require.NoError(t, os.WriteFile(tsqlPath, []byte(tsqlContent), 0o644))

	expectedPLpgSQL := `CREATE OR REPLACE FUNCTION aion_world_live.aion_GetGuildId(p_strGuildName VARCHAR(32))
RETURNS TABLE(id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY SELECT g."id" FROM "guild" g WHERE g."name" = p_strGuildName;
END;
$$;`

	s := &Synthesizer{
		LLM: &FakeLLMClient{FixedResponse: expectedPLpgSQL},
	}

	result, err := s.Synth(tsqlPath, SchemaContext{})
	require.NoError(t, err)
	assert.Equal(t, expectedPLpgSQL, result.PLpgSQL)
	assert.Equal(t, "fake", result.Provenance.LLMModel)
	assert.Greater(t, result.Provenance.TSQLLineCount, 0)
	assert.Equal(t, "none", result.EquivEvidence.ValidationMethod)
}

// ─────────────────────────────────────────────────────────────────────────────
// 测试 2：含 IF/ELSE 分支的 SP
// ─────────────────────────────────────────────────────────────────────────────

// TestSynth_IfElseBranch 验证含 IF/ELSE 分支的 T-SQL 合成结果中保留分支逻辑。
func TestSynth_IfElseBranch(t *testing.T) {
	dir := t.TempDir()
	tsqlPath := filepath.Join(dir, "aion_GetItemByWarehouse.sql")
	tsqlContent := `CREATE PROCEDURE [dbo].[aion_GetItemByWarehouse]
    @charid int, @warehouse int
AS
BEGIN
    IF @warehouse = 0
        SELECT id, name_id, amount FROM user_item WHERE char_id = @charid AND warehouse = 0
    ELSE
        SELECT id, name_id, amount FROM user_item WHERE char_id = @charid AND warehouse = @warehouse
END`
	require.NoError(t, os.WriteFile(tsqlPath, []byte(tsqlContent), 0o644))

	expectedPLpgSQL := `CREATE OR REPLACE FUNCTION aion_world_live.aion_GetItemByWarehouse(
    p_charid INTEGER, p_warehouse INTEGER
) RETURNS TABLE(id INTEGER, name_id INTEGER, amount INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_warehouse = 0 THEN
        RETURN QUERY SELECT ui."id", ui."name_id", ui."amount"
            FROM "user_item" ui WHERE ui."char_id" = p_charid AND ui."warehouse" = 0;
    ELSE
        RETURN QUERY SELECT ui."id", ui."name_id", ui."amount"
            FROM "user_item" ui WHERE ui."char_id" = p_charid AND ui."warehouse" = p_warehouse;
    END IF;
END;
$$;`

	s := &Synthesizer{LLM: &FakeLLMClient{FixedResponse: expectedPLpgSQL}}
	result, err := s.Synth(tsqlPath, SchemaContext{})
	require.NoError(t, err)
	// 验证生成结果包含 IF/ELSE 结构（PL/pgSQL 的 IF...THEN...ELSE...END IF）
	assert.Contains(t, result.PLpgSQL, "IF p_warehouse = 0 THEN")
	assert.Contains(t, result.PLpgSQL, "ELSE")
	assert.Contains(t, result.PLpgSQL, "END IF")
}

// ─────────────────────────────────────────────────────────────────────────────
// 测试 3：含临时表的 SP — 验证 prompt 中 conversion-rules 存在 #tmp→TEMP TABLE 规则
// ─────────────────────────────────────────────────────────────────────────────

// TestSynth_TempTable_PromptContainsRule 验证含临时表的 T-SQL 生成的 prompt，
// 必须包含 "#tmp_table（临时表）→ CREATE TEMP TABLE" 转换规则。
// 这是 LLM 正确转换临时表语法的关键 prompt 内容。
func TestSynth_TempTable_PromptContainsRule(t *testing.T) {
	tsql := `CREATE PROCEDURE [dbo].[aion_CalcTop10]
AS
BEGIN
    SELECT TOP 10 char_id, abyss_point INTO #top10 FROM characters ORDER BY abyss_point DESC
    SELECT * FROM #top10
    DROP TABLE #top10
END`

	schema := SchemaContext{}
	prompt := TsqlToPlpgsqlPrompt(tsql, schema)

	// 验证 prompt 中包含临时表转换规则
	assert.Contains(t, prompt, "#tmp_table（临时表）", "prompt 必须包含临时表转换规则")
	assert.Contains(t, prompt, "CREATE TEMP TABLE", "prompt 必须说明 TEMP TABLE 替换方式")
}

// ─────────────────────────────────────────────────────────────────────────────
// 测试 4：影子流量对比 100 行 0 diff
// ─────────────────────────────────────────────────────────────────────────────

// TestShadow_100Rows_ZeroDiff 验证两侧完全一致时 ShadowValidator 报告 Equal=true。
func TestShadow_100Rows_ZeroDiff(t *testing.T) {
	// 构造 100 行完全相同的输出数据
	rows := make([][]any, 100)
	for i := range rows {
		rows[i] = []any{i + 1, int64(i * 1000)}
	}

	// 构造 100 组 inputSet（每组参数不同，但两侧返回相同行）
	inputSet := make([][]any, 100)
	for i := range inputSet {
		inputSet[i] = []any{i + 1}
	}

	tsqlRunner := &staticQueryRunner{rows: rows}
	pgRunner := &staticQueryRunner{rows: rows}

	sv := &ShadowValidator{
		TSQLRunner: tsqlRunner,
		PGRunner:   pgRunner,
		InputSet:   inputSet,
	}

	report, err := sv.Validate("", "")
	require.NoError(t, err)
	assert.True(t, report.Equal, "100 行完全一致，应 Equal=true")
	assert.Equal(t, 0, report.DiffCount)
}

// ─────────────────────────────────────────────────────────────────────────────
// 测试 5：影子流量对比 100 行 5 diff — 验证报告生成
// ─────────────────────────────────────────────────────────────────────────────

// TestShadow_100Rows_FiveDiff 验证两侧有 5 行不同时，DiffReport 正确记录 5 条差异。
func TestShadow_100Rows_FiveDiff(t *testing.T) {
	rng := rand.New(rand.NewSource(99))

	// 构造基础行集和故意引入 5 处差异的 PG 行集
	baseRows := make([][]any, 1) // 每次 Run 返回 1 行
	pgRows := make([][]any, 1)

	// 准备 100 组 inputSet
	inputSet := make([][]any, 100)
	for i := range inputSet {
		inputSet[i] = []any{rng.Int()}
	}

	diffIndexes := map[int]bool{10: true, 30: true, 55: true, 77: true, 99: true}

	callCount := 0
	// 使用 callbackQueryRunner 按调用次数决定返回值
	tsqlCB := &callbackQueryRunner{
		fn: func(args []any) ([][]any, error) {
			idx := callCount / 2 // tsql 每次调用偶数次
			callCount++
			return [][]any{{idx, "value"}}, nil
		},
	}
	pgCB := &callbackQueryRunner{
		fn: func(args []any) ([][]any, error) {
			// 故意在 5 个特定索引返回不同值
			idx := callCount / 2
			callCount++
			if diffIndexes[idx] {
				return [][]any{{idx, "WRONG"}}, nil
			}
			return [][]any{{idx, "value"}}, nil
		},
	}
	_ = baseRows
	_ = pgRows

	// 重置 callCount 并重新构建验证器
	callCount = 0
	sv := &ShadowValidator{
		TSQLRunner: tsqlCB,
		PGRunner:   pgCB,
		InputSet:   inputSet,
	}

	report, err := sv.Validate("", "")
	require.NoError(t, err)
	assert.False(t, report.Equal, "存在 5 处差异，Equal 应为 false")
	assert.Equal(t, 5, report.DiffCount, "应恰好有 5 条差异")
}

// callbackQueryRunner 是一个基于回调函数的 QueryRunner mock，
// 允许在测试中按调用顺序控制返回值。
type callbackQueryRunner struct {
	fn func(args []any) ([][]any, error)
}

func (c *callbackQueryRunner) Run(args []any) ([][]any, error) {
	return c.fn(args)
}

// TestPrompt_ContainsAllSections 验证 TsqlToPlpgsqlPrompt 生成的 prompt 包含所有必要段落。
func TestPrompt_ContainsAllSections(t *testing.T) {
	tsql := "SELECT id FROM guild WHERE name = @strGuildName"
	prompt := TsqlToPlpgsqlPrompt(tsql, SchemaContext{})

	sections := []string{
		"=== SYSTEM ===",
		"=== ROLE ===",
		"=== STYLE ===",
		"=== SCHEMA CONTEXT ===",
		"=== CONVERSION RULES ===",
		"=== FEW-SHOTS ===",
		"=== OUTPUT FORMAT ===",
		"=== INPUT T-SQL ===",
		"=== OUTPUT PL/pgSQL ===",
	}
	for _, sec := range sections {
		assert.Contains(t, prompt, sec, "prompt 必须包含段落: %s", sec)
	}

	// 验证输入 T-SQL 被嵌入 prompt
	assert.Contains(t, prompt, tsql)

	// 验证 PG 双引号规则存在
	assert.True(t,
		strings.Contains(prompt, `双引号`) || strings.Contains(prompt, `"`),
		"prompt 应提示使用双引号包裹标识符",
	)
}
