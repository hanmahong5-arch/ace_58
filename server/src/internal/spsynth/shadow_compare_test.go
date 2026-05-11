package spsynth

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestCompareOutputs_BothEmpty 验证两个空结果集视为等价。
func TestCompareOutputs_BothEmpty(t *testing.T) {
	report := CompareOutputs(nil, nil)
	assert.True(t, report.Equal, "两个空结果集应等价")
	assert.Equal(t, 0, report.DiffCount)
	assert.Equal(t, 0, report.TotalRows)
}

// TestCompareOutputs_IdenticalRows 验证完全相同的行集（包括顺序不同的情况）视为等价。
func TestCompareOutputs_IdenticalRows(t *testing.T) {
	tsqlOut := [][]any{{1, "guild_a"}, {2, "guild_b"}}
	pgOut := [][]any{{2, "guild_b"}, {1, "guild_a"}} // 顺序不同

	report := CompareOutputs(tsqlOut, pgOut)
	assert.True(t, report.Equal, "顺序不同但内容相同的结果集应等价")
	assert.Equal(t, 0, report.DiffCount)
}

// TestCompareOutputs_ExtraRowInPG 验证 PG 侧多一行时 DiffCount 正确。
func TestCompareOutputs_ExtraRowInPG(t *testing.T) {
	tsqlOut := [][]any{{1, "guild_a"}}
	pgOut := [][]any{{1, "guild_a"}, {2, "guild_b"}} // PG 多一行

	report := CompareOutputs(tsqlOut, pgOut)
	assert.False(t, report.Equal)
	assert.Equal(t, 1, report.DiffCount)
	assert.Equal(t, "PG 侧多余行", report.Diffs[0].Reason)
}

// TestCompareOutputs_ExtraRowInTSQL 验证 T-SQL 侧多一行时 DiffCount 正确。
func TestCompareOutputs_ExtraRowInTSQL(t *testing.T) {
	tsqlOut := [][]any{{1, "guild_a"}, {3, "guild_c"}} // T-SQL 多一行
	pgOut := [][]any{{1, "guild_a"}}

	report := CompareOutputs(tsqlOut, pgOut)
	assert.False(t, report.Equal)
	assert.Equal(t, 1, report.DiffCount)
	assert.Equal(t, "T-SQL 侧多余行", report.Diffs[0].Reason)
}

// TestCompareOutputs_ValueMismatch 验证相同行数但值不同时报告差异。
func TestCompareOutputs_ValueMismatch(t *testing.T) {
	tsqlOut := [][]any{{1, "guild_a"}, {2, "guild_b"}}
	pgOut := [][]any{{1, "guild_a"}, {2, "WRONG_NAME"}} // 第 2 行值不同

	report := CompareOutputs(tsqlOut, pgOut)
	assert.False(t, report.Equal)
	assert.Equal(t, 1, report.DiffCount)
	assert.Contains(t, report.Diffs[0].Reason, "值不匹配")
}
