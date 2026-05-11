package spsynth

import (
	"fmt"
	"math"
	"reflect"
	"sort"
)

// RowDiff 描述两个结果集中某一行的差异（按排序后位置对齐）。
type RowDiff struct {
	// RowIndex 是排序后结果集中的行索引（0-based）
	RowIndex int
	// TSQLRow 是 T-SQL 侧的行数据（nil 表示该行在 T-SQL 侧不存在）
	TSQLRow []any
	// PGRow 是 PG 侧的行数据（nil 表示该行在 PG 侧不存在）
	PGRow []any
	// Reason 描述差异原因
	Reason string
}

// DiffReport 汇总两个结果集的对比结果。
type DiffReport struct {
	// TotalRows 是较大那侧的行数
	TotalRows int
	// DiffCount 是存在差异的行数
	DiffCount int
	// Diffs 是所有差异的明细列表（上限 100 条，避免过大）
	Diffs []RowDiff
	// Equal 为 true 表示两个结果集完全等价
	Equal bool
}

// rowKey 将一行数据序列化为可比较的字符串键，用于集合对比。
func rowKey(row []any) string {
	return fmt.Sprintf("%v", row)
}

// normalizeValue 对常见 float64 精度差异做容忍处理。
// 两值差异在 1e-9 以内视为相等。
func normalizeValue(a, b any) bool {
	fa, aIsFloat := toFloat64(a)
	fb, bIsFloat := toFloat64(b)
	if aIsFloat && bIsFloat {
		return math.Abs(fa-fb) < 1e-9
	}
	return reflect.DeepEqual(a, b)
}

func toFloat64(v any) (float64, bool) {
	switch x := v.(type) {
	case float32:
		return float64(x), true
	case float64:
		return x, true
	case int:
		return float64(x), true
	case int32:
		return float64(x), true
	case int64:
		return float64(x), true
	}
	return 0, false
}

// rowsEqual 逐列比较两行，忽略 float 精度误差。
func rowsEqual(a, b []any) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if !normalizeValue(a[i], b[i]) {
			return false
		}
	}
	return true
}

// sortRows 对结果集按行的字符串键排序，消除行顺序差异。
// 注意：此操作会修改传入切片，调用方需传入副本。
func sortRows(rows [][]any) {
	sort.Slice(rows, func(i, j int) bool {
		return rowKey(rows[i]) < rowKey(rows[j])
	})
}

// copyRows 深拷贝一个结果集，避免排序修改原始数据。
func copyRows(src [][]any) [][]any {
	dst := make([][]any, len(src))
	copy(dst, src)
	return dst
}

// CompareOutputs 对比 T-SQL 侧与 PG 侧的查询结果集，生成 DiffReport。
// 忽略行顺序（排序对齐），但严格比较类型和值（float 容忍 1e-9 误差）。
// 空结果集视为等价。
func CompareOutputs(tsqlOut, pgOut [][]any) DiffReport {
	tsqlSorted := copyRows(tsqlOut)
	pgSorted := copyRows(pgOut)
	sortRows(tsqlSorted)
	sortRows(pgSorted)

	maxLen := len(tsqlSorted)
	if len(pgSorted) > maxLen {
		maxLen = len(pgSorted)
	}

	report := DiffReport{TotalRows: maxLen}

	const diffCap = 100 // 最多收集 100 条差异，防止报告过大

	for i := 0; i < maxLen && len(report.Diffs) < diffCap; i++ {
		var tsqlRow, pgRow []any

		if i < len(tsqlSorted) {
			tsqlRow = tsqlSorted[i]
		}
		if i < len(pgSorted) {
			pgRow = pgSorted[i]
		}

		switch {
		case tsqlRow == nil:
			report.Diffs = append(report.Diffs, RowDiff{
				RowIndex: i, TSQLRow: nil, PGRow: pgRow,
				Reason: "PG 侧多余行",
			})
		case pgRow == nil:
			report.Diffs = append(report.Diffs, RowDiff{
				RowIndex: i, TSQLRow: tsqlRow, PGRow: nil,
				Reason: "T-SQL 侧多余行",
			})
		case !rowsEqual(tsqlRow, pgRow):
			report.Diffs = append(report.Diffs, RowDiff{
				RowIndex: i, TSQLRow: tsqlRow, PGRow: pgRow,
				Reason: fmt.Sprintf("值不匹配: T-SQL=%v  PG=%v", tsqlRow, pgRow),
			})
		}
	}

	report.DiffCount = len(report.Diffs)
	report.Equal = report.DiffCount == 0
	return report
}
