// Package memory — Retriever 负责多因子评分的记忆召回。
package memory

import (
	"math"
	"sort"
	"time"
)

// Retriever 封装记忆召回逻辑，组合向量相似度、重要度、时间衰减三项评分。
//
// 最终评分公式（各项均归一化到 [0,1]）：
//
//	score = cosineSim * 0.7 + importance * 0.3 + timeDecay * bonus
//
// 注意：timeDecay 作为奖励项（非惩罚），越新的记忆分越高，
// 具体权重见 recencyBonus 常量。
type Retriever struct {
	store VectorStore
}

// NewRetriever 创建绑定指定 VectorStore 的 Retriever。
func NewRetriever(store VectorStore) *Retriever {
	return &Retriever{store: store}
}

// recencyBonus 时间衰减奖励权重。
// 设计为较小值，保证内容相关性（0.7）主导，时效性为辅助。
const recencyBonus = 0.15

// halfLifeDays 时间衰减半衰期，单位天。
// 7 天后记忆衰减至约 50%；30 天后约 10%。
const halfLifeDays = 7.0

// scoredEntry 内部排序用结构，不导出。
type scoredEntry struct {
	entry MemoryEntry
	score float64
}

// Recall 在 npcID+playerID 范围内召回与 query 最相关的 topK 条记忆。
//
// 评分 = 向量相似度*0.7 + importance*0.3 + 时间衰减奖励*recencyBonus。
// query 为调用方提供的查询向量（16 维占位）；
// 若 query 为 nil 或零向量，向量相似度贡献 0，退化为重要度+时效排序。
func (r *Retriever) Recall(npcID, playerID int64, query []float32, topK int) ([]MemoryEntry, error) {
	if topK <= 0 {
		return nil, nil
	}

	// 向量存储层返回候选集（无需再次过滤 npcID/playerID，存储层已处理）。
	candidates, err := r.store.Search(npcID, playerID, query, topK*3) // 取 3 倍以便重排
	if err != nil {
		return nil, err
	}
	if len(candidates) == 0 {
		return nil, nil
	}

	now := time.Now()
	normalizedQuery := normalize(query)

	scored := make([]scoredEntry, 0, len(candidates))
	for _, e := range candidates {
		simScore := cosineSim(normalizedQuery, e.Embedding)
		importanceScore := float64(e.Importance)
		decayScore := timeDecay(e.CreatedAt, now)

		total := simScore*0.7 + importanceScore*0.3 + decayScore*recencyBonus
		scored = append(scored, scoredEntry{entry: e, score: total})
	}

	// 降序排列，取 topK。
	sort.Slice(scored, func(i, j int) bool {
		return scored[i].score > scored[j].score
	})

	if len(scored) > topK {
		scored = scored[:topK]
	}

	result := make([]MemoryEntry, len(scored))
	for i, s := range scored {
		result[i] = s.entry
	}
	return result, nil
}

// cosineSim 计算两个已归一化向量的余弦相似度。
// 若任一向量为空或全零，返回 0。
func cosineSim(a, b []float32) float64 {
	if len(a) == 0 || len(b) == 0 || len(a) != len(b) {
		return 0
	}
	var dot float64
	for i := range a {
		dot += float64(a[i]) * float64(b[i])
	}
	// 因已归一化，点积即为余弦值，截断到 [0,1]。
	if dot < 0 {
		dot = 0
	}
	if dot > 1 {
		dot = 1
	}
	return dot
}

// normalize 返回向量的 L2 归一化副本。
// 若向量为 nil 或模为零，返回与输入等长的零向量。
func normalize(v []float32) []float32 {
	if len(v) == 0 {
		return nil
	}
	var sumSq float64
	for _, x := range v {
		sumSq += float64(x) * float64(x)
	}
	if sumSq == 0 {
		out := make([]float32, len(v))
		return out
	}
	mag := math.Sqrt(sumSq)
	out := make([]float32, len(v))
	for i, x := range v {
		out[i] = float32(float64(x) / mag)
	}
	return out
}

// timeDecay 按指数衰减返回 [0,1] 的时效分。
// createdAt 越接近 now，值越高；halfLifeDays 控制衰减速率。
func timeDecay(createdAt, now time.Time) float64 {
	age := now.Sub(createdAt).Hours() / 24.0 // 转天数
	if age < 0 {
		age = 0
	}
	// 指数衰减：decay = 2^(-age/halfLife)
	return math.Pow(2, -age/halfLifeDays)
}
