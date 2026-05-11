package spsynth

import "fmt"

// LLMClient 定义 LLM 转换接口，允许替换真实 HTTP 客户端或测试 stub。
// 调用方传入完整 prompt 字符串，期望返回 PL/pgSQL 函数体文本。
type LLMClient interface {
	// Convert 发送 prompt 到 LLM，返回生成的 PL/pgSQL 代码字符串。
	// 失败时返回非 nil error，调用方应记录并重试。
	Convert(prompt string) (string, error)
}

// FakeLLMClient 是 LLMClient 的测试 stub，直接返回预设的固定响应。
// 不发起任何网络请求，适用于单元测试和 CI 环境。
type FakeLLMClient struct {
	// FixedResponse 是每次 Convert 调用都会原样返回的 PL/pgSQL 文本。
	FixedResponse string
	// Err 若非 nil，则 Convert 返回此错误（用于测试错误路径）。
	Err error
	// CallCount 记录 Convert 被调用的次数，便于断言调用行为。
	CallCount int
}

// Convert 返回预设的 FixedResponse，或在 Err 非 nil 时返回错误。
func (f *FakeLLMClient) Convert(prompt string) (string, error) {
	f.CallCount++
	if f.Err != nil {
		return "", fmt.Errorf("FakeLLMClient: 预设错误: %w", f.Err)
	}
	return f.FixedResponse, nil
}
