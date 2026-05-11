// Package memory 提供 NPC 记忆层的数据结构和向量存储接口。
//
// 设计意图：
//   - MemoryEntry 是 NPC 对玩家单次交互的记忆单元，含文本内容和轻量向量表示。
//   - Embedding 当前为 16 维占位（float32 切片），未来替换为真实嵌入向量。
//   - VectorStore 接口隔离存储实现（内存 FakeStore / Qdrant / pgvector），
//     确保上层 Retriever 无需感知底层存储细节。
//   - 本包无任何网络或 DB 依赖，可在无外部服务的单元测试环境下运行。
package memory

import "time"

// MemoryEntry 表示 NPC 对一次玩家交互的记忆记录。
type MemoryEntry struct {
	// ID 记忆唯一标识（UUID 字符串或雪花 ID）。
	ID string

	// NpcID 记忆归属 NPC 的模板 ID。
	NpcID int64

	// PlayerID 触发本次记忆的玩家角色 ID。
	PlayerID int64

	// Content 自然语言描述的记忆内容，如"玩家首次击败深渊首领"。
	Content string

	// EventType 事件类型标签，方便过滤检索，如 "quest_complete"、"first_meet"。
	EventType string

	// Importance 重要度评分 [0.0, 1.0]；0.0 = 最不重要，1.0 = 关键记忆。
	// Director 层写入时赋值；影响 Retriever 评分权重。
	Importance float32

	// CreatedAt 记忆生成时间，用于时间衰减计算。
	CreatedAt time.Time

	// Embedding 16 维占位向量，当前为零向量或随机初始化。
	// 接入真实嵌入模型后替换为 1536 维（OpenAI text-embedding-3-small）。
	Embedding []float32
}

// VectorStore 向量存储的抽象接口。
// 实现方可以是内存 FakeVectorStore、Qdrant、pgvector 等。
type VectorStore interface {
	// Upsert 插入或更新记忆条目。
	// 若 entry.ID 已存在则整条覆盖（语义：记忆更新而非追加）。
	Upsert(entry MemoryEntry) error

	// Search 在指定 NpcID+PlayerID 范围内按向量相似度检索 topK 条记忆。
	// query 为查询向量（与 entry.Embedding 同维度）。
	Search(npcID, playerID int64, query []float32, topK int) ([]MemoryEntry, error)

	// Delete 按 ID 删除单条记忆。找不到时静默成功（幂等）。
	Delete(id string) error
}

// embeddingDim 是当前占位向量维度。
// 修改此常量时需同步更新 fake_store.go 中的相似度计算。
const embeddingDim = 16
