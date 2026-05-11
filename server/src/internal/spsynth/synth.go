package spsynth

import (
	"fmt"
	"os"
	"strings"
)

// Provenance 记录本次合成的来源元信息，供审计和版本管理使用。
type Provenance struct {
	// SourcePath 是输入 T-SQL 文件的绝对路径
	SourcePath string
	// TSQLLineCount 是原始 T-SQL 的行数
	TSQLLineCount int
	// LLMModel 是执行转换的 LLM 模型标识（stub 阶段为 "fake"）
	LLMModel string
	// PromptHash 是 prompt 字符串的简单摘要（前 64 字符）
	PromptHash string
}

// EquivEvidence 汇总等价性验证结果，提供人工审核所需的证据链。
type EquivEvidence struct {
	// ValidationMethod 描述验证方法（"property" / "shadow" / "none"）
	ValidationMethod string
	// Report 是最终 DiffReport
	Report DiffReport
	// Passed 为 true 表示验证通过（DiffCount == 0）
	Passed bool
}

// SynthResult 是一次成功合成的完整输出。
type SynthResult struct {
	// PLpgSQL 是生成的 PL/pgSQL 函数文本
	PLpgSQL string
	// Provenance 是来源元信息
	Provenance Provenance
	// EquivEvidence 是等价性验证证据
	EquivEvidence EquivEvidence
}

// Synthesizer 封装从 T-SQL → PL/pgSQL 的完整合成流程。
// 依赖注入 LLMClient，测试时使用 FakeLLMClient，生产时替换为真实 HTTP 客户端。
type Synthesizer struct {
	// LLM 是 LLM 转换客户端
	LLM LLMClient
	// Validator 是等价性验证器（可为 nil，跳过验证）
	Validator Validator
}

// Synth 读取 tsqlPath 文件，构建 prompt，调用 LLM 生成 PL/pgSQL，
// 并可选地运行等价性验证，返回 SynthResult。
// 整个流程为纯函数式：不修改磁盘，不写数据库。
func (s *Synthesizer) Synth(tsqlPath string, schemaCtx SchemaContext) (SynthResult, error) {
	// 1. 读取 T-SQL 源文件
	raw, err := os.ReadFile(tsqlPath)
	if err != nil {
		return SynthResult{}, fmt.Errorf("Synth: 读取文件 %q 失败: %w", tsqlPath, err)
	}
	tsqlText := string(raw)
	lineCount := strings.Count(tsqlText, "\n") + 1

	// 2. 构建 prompt
	prompt := TsqlToPlpgsqlPrompt(tsqlText, schemaCtx)

	// 3. 调用 LLM 转换
	plpgsql, err := s.LLM.Convert(prompt)
	if err != nil {
		return SynthResult{}, fmt.Errorf("Synth: LLM 转换失败: %w", err)
	}
	if strings.TrimSpace(plpgsql) == "" {
		return SynthResult{}, fmt.Errorf("Synth: LLM 返回空 PL/pgSQL，转换可能失败")
	}

	// 4. 构建来源元信息
	prov := Provenance{
		SourcePath:    tsqlPath,
		TSQLLineCount: lineCount,
		LLMModel:      llmModelName(s.LLM),
		PromptHash:    promptSummary(prompt),
	}

	// 5. 可选等价性验证
	evidence := EquivEvidence{ValidationMethod: "none"}
	if s.Validator != nil {
		report, verr := s.Validator.Validate(tsqlText, plpgsql)
		if verr != nil {
			// 验证器运行失败不视为合成失败，但在 evidence 中记录
			evidence = EquivEvidence{
				ValidationMethod: "error",
				Report:           DiffReport{},
				Passed:           false,
			}
		} else {
			evidence = EquivEvidence{
				ValidationMethod: "validator",
				Report:           report,
				Passed:           report.Equal,
			}
		}
	}

	return SynthResult{
		PLpgSQL:       plpgsql,
		Provenance:    prov,
		EquivEvidence: evidence,
	}, nil
}

// llmModelName 从 LLMClient 实现类型推断模型名称标识。
func llmModelName(llm LLMClient) string {
	if _, ok := llm.(*FakeLLMClient); ok {
		return "fake"
	}
	return "unknown"
}

// promptSummary 取 prompt 前 64 字符作为简短摘要，用于日志和审计。
func promptSummary(prompt string) string {
	if len(prompt) <= 64 {
		return prompt
	}
	return prompt[:64] + "..."
}
