// Package memory — FakeVectorStore 是 VectorStore 的纯内存实现，供单元测试使用。
//
// 相似度算法：原始余弦相似度（含 L2 归一化），与 Retriever 内部评分保持一致。
// 线程安全：通过 sync.RWMutex 保护 entries 切片。
package memory

import (
	"sync"
)

// FakeVectorStore 内存向量存储，不依赖任何外部服务。
// 在测试场景和开发阶段直接使用，生产环境替换为 Qdrant/pgvector 实现。
type FakeVectorStore struct {
	mu      sync.RWMutex
	entries []MemoryEntry
}

// NewFakeVectorStore 创建空内存存储。
func NewFakeVectorStore() *FakeVectorStore {
	return &FakeVectorStore{}
}

// Upsert 插入或按 ID 覆盖记忆条目。
func (f *FakeVectorStore) Upsert(entry MemoryEntry) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	for i, e := range f.entries {
		if e.ID == entry.ID {
			f.entries[i] = entry
			return nil
		}
	}
	f.entries = append(f.entries, entry)
	return nil
}

// Search 在 npcID+playerID 范围内按余弦相似度返回最多 topK 条记忆。
// 若 query 为 nil 则相似度全为 0，退化为按插入顺序返回。
func (f *FakeVectorStore) Search(npcID, playerID int64, query []float32, topK int) ([]MemoryEntry, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()

	if topK <= 0 {
		return nil, nil
	}

	normQ := normalize(query)

	type pair struct {
		e    MemoryEntry
		sim  float64
	}

	var candidates []pair
	for _, e := range f.entries {
		// 过滤 NPC 和玩家范围
		if e.NpcID != npcID || e.PlayerID != playerID {
			continue
		}
		normE := normalize(e.Embedding)
		sim := cosineSim(normQ, normE)
		candidates = append(candidates, pair{e: e, sim: sim})
	}

	// 按相似度降序，取 topK（插入排序，候选集小时足够高效）。
	for i := 1; i < len(candidates); i++ {
		for j := i; j > 0 && candidates[j].sim > candidates[j-1].sim; j-- {
			candidates[j], candidates[j-1] = candidates[j-1], candidates[j]
		}
	}

	if len(candidates) > topK {
		candidates = candidates[:topK]
	}

	result := make([]MemoryEntry, len(candidates))
	for i, p := range candidates {
		result[i] = p.e
	}
	return result, nil
}

// Delete 按 ID 删除记忆，找不到时静默成功。
func (f *FakeVectorStore) Delete(id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	for i, e := range f.entries {
		if e.ID == id {
			// 用末尾元素填坑，避免移动大切片
			f.entries[i] = f.entries[len(f.entries)-1]
			f.entries = f.entries[:len(f.entries)-1]
			return nil
		}
	}
	return nil
}

// Len 返回当前存储的记忆条目数，用于测试断言。
func (f *FakeVectorStore) Len() int {
	f.mu.RLock()
	defer f.mu.RUnlock()
	return len(f.entries)
}

// 编译期确保 FakeVectorStore 实现 VectorStore 接口。
var _ VectorStore = (*FakeVectorStore)(nil)
