package spsynth

import (
	"fmt"
	"math/rand"
)

// Validator 定义等价性验证接口。
// 不同实现可用于属性测试（随机输入）或影子流量对比（真实 input set）。
type Validator interface {
	// Validate 验证 T-SQL 侧和 PG 侧的等价性，返回 DiffReport 和可能的运行错误。
	Validate(tsql, plpgsql string) (DiffReport, error)
}

// QueryRunner 抽象查询执行器，允许注入真实 DB 连接或 mock。
// 每次调用 Run 以给定参数执行存储过程/函数，返回结果行集。
type QueryRunner interface {
	// Run 以 args 参数执行目标查询，返回 [][]any 行集。
	Run(args []any) ([][]any, error)
}

// ─────────────────────────────────────────────────────────────────────────────
// PropertyValidator：随机输入属性测试
// ─────────────────────────────────────────────────────────────────────────────

// PropertyValidator 通过随机生成输入参数，对两侧实现跑对比，
// 实现基于属性测试（Property-Based Testing）的等价性验证。
// tsqlRunner / pgRunner 是注入的执行器，测试时可使用 mock 实现。
type PropertyValidator struct {
	// TSQLRunner 执行原始 T-SQL 侧
	TSQLRunner QueryRunner
	// PGRunner 执行生成的 PL/pgSQL 侧
	PGRunner QueryRunner
	// Rounds 是随机测试轮数（默认建议 50~200）
	Rounds int
	// Rng 是随机数生成器，注入以保证测试可重现
	Rng *rand.Rand
	// ArgGenerator 根据轮次生成参数，调用方按 SP 签名实现
	ArgGenerator func(round int, rng *rand.Rand) []any
}

// Validate 对 tsql/plpgsql 文本各运行 p.Rounds 次随机参数对比。
// tsql 和 plpgsql 参数目前作为元信息记录，实际执行通过注入的 Runner 完成。
func (p *PropertyValidator) Validate(tsql, plpgsql string) (DiffReport, error) {
	if p.TSQLRunner == nil || p.PGRunner == nil {
		return DiffReport{}, fmt.Errorf("PropertyValidator: TSQLRunner 和 PGRunner 不能为 nil")
	}
	if p.ArgGenerator == nil {
		return DiffReport{}, fmt.Errorf("PropertyValidator: ArgGenerator 不能为 nil")
	}
	rounds := p.Rounds
	if rounds <= 0 {
		rounds = 50
	}
	rng := p.Rng
	if rng == nil {
		rng = rand.New(rand.NewSource(42)) //nolint:gosec // 测试用固定种子
	}

	var allDiffs []RowDiff
	totalRows := 0

	for i := 0; i < rounds; i++ {
		args := p.ArgGenerator(i, rng)

		tsqlRows, err := p.TSQLRunner.Run(args)
		if err != nil {
			return DiffReport{}, fmt.Errorf("PropertyValidator: 第 %d 轮 T-SQL 执行失败: %w", i, err)
		}
		pgRows, err := p.PGRunner.Run(args)
		if err != nil {
			return DiffReport{}, fmt.Errorf("PropertyValidator: 第 %d 轮 PG 执行失败: %w", i, err)
		}

		report := CompareOutputs(tsqlRows, pgRows)
		totalRows += report.TotalRows
		allDiffs = append(allDiffs, report.Diffs...)
	}

	return DiffReport{
		TotalRows: totalRows,
		DiffCount: len(allDiffs),
		Diffs:     allDiffs,
		Equal:     len(allDiffs) == 0,
	}, nil
}

// ─────────────────────────────────────────────────────────────────────────────
// ShadowValidator：影子流量对比
// ─────────────────────────────────────────────────────────────────────────────

// ShadowValidator 使用预先录制的真实 input set（影子流量）对两侧进行对比。
// 适合生产环境回放，比纯随机属性测试更贴近真实场景。
type ShadowValidator struct {
	// TSQLRunner 执行原始 T-SQL 侧
	TSQLRunner QueryRunner
	// PGRunner 执行生成的 PL/pgSQL 侧
	PGRunner QueryRunner
	// InputSet 是预先录制的参数组列表，每个元素是一次调用的参数 slice
	InputSet [][]any
}

// Validate 按 InputSet 中每组参数执行两侧对比，聚合 DiffReport。
func (s *ShadowValidator) Validate(tsql, plpgsql string) (DiffReport, error) {
	if s.TSQLRunner == nil || s.PGRunner == nil {
		return DiffReport{}, fmt.Errorf("ShadowValidator: TSQLRunner 和 PGRunner 不能为 nil")
	}

	var allDiffs []RowDiff
	totalRows := 0

	for i, args := range s.InputSet {
		tsqlRows, err := s.TSQLRunner.Run(args)
		if err != nil {
			return DiffReport{}, fmt.Errorf("ShadowValidator: 第 %d 组 T-SQL 执行失败: %w", i, err)
		}
		pgRows, err := s.PGRunner.Run(args)
		if err != nil {
			return DiffReport{}, fmt.Errorf("ShadowValidator: 第 %d 组 PG 执行失败: %w", i, err)
		}

		report := CompareOutputs(tsqlRows, pgRows)
		totalRows += report.TotalRows
		allDiffs = append(allDiffs, report.Diffs...)
	}

	return DiffReport{
		TotalRows: totalRows,
		DiffCount: len(allDiffs),
		Diffs:     allDiffs,
		Equal:     len(allDiffs) == 0,
	}, nil
}
