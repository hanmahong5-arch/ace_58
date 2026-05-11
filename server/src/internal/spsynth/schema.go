// Package spsynth 提供 T-SQL 存储过程到 PL/pgSQL 的 LLM Agentic 合成框架。
// 核心流程：输入 T-SQL 文件 + Schema 上下文 → LLM 转换 → 形式化等价验证 → SynthResult。
package spsynth

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// TableInfo 描述单张数据库表的元信息，供 prompt 构建和验证器使用。
type TableInfo struct {
	// Name 是表名（PostgreSQL 双引号风格，例如 "guild"）
	Name string
	// Columns 是列名列表（同样保留双引号风格）
	Columns []string
	// PrimaryKey 是主键列名
	PrimaryKey string
}

// SpInfo 描述一个已知存储过程的签名，用于 schema 上下文。
type SpInfo struct {
	// Name 是存储过程名（无 schema 前缀）
	Name string
	// Params 是参数名列表（保留原始 T-SQL @参数名 或已去掉 @ 的形式）
	Params []string
	// ReturnType 描述返回类型，例如 "TABLE" / "VOID" / "SCALAR int"
	ReturnType string
}

// SchemaContext 封装生成 prompt 与运行验证所需的数据库 schema 信息。
type SchemaContext struct {
	// Tables 是相关表信息列表
	Tables []TableInfo
	// SPs 是已知存储过程签名列表（供 few-shot 对比使用）
	SPs []SpInfo
	// CurrentDialect 标识源 dialect，目前固定为 "tsql"
	CurrentDialect string
}

// LoadFromDump 从 dump 目录扫描 .sql 文件，提取存储过程名称，构建最小 SchemaContext。
// 当前为 stub 实现，仅枚举文件名作为 SpInfo.Name；
// 完整实现需解析 CREATE PROCEDURE 签名，留待后续 Sprint 迭代。
func LoadFromDump(dir string) (SchemaContext, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return SchemaContext{}, fmt.Errorf("LoadFromDump: 读取目录 %q 失败: %w", dir, err)
	}

	var sps []SpInfo
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		spName := strings.TrimSuffix(filepath.Base(e.Name()), ".sql")
		sps = append(sps, SpInfo{
			Name:       spName,
			Params:     nil, // stub：待 Sprint 1 解析
			ReturnType: "UNKNOWN",
		})
	}

	return SchemaContext{
		CurrentDialect: "tsql",
		SPs:            sps,
	}, nil
}
