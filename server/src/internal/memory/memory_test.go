package memory

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	testNpcID    int64 = 900001
	testPlayerID int64 = 100001
)

// makeEntry 创建指定参数的测试记忆条目，embedding 为均匀分量向量。
func makeEntry(id string, content string, importance float32, age time.Duration) MemoryEntry {
	// 构造非零 embedding，每个分量等于 1/sqrt(dim)（归一化向量）。
	emb := make([]float32, embeddingDim)
	val := float32(1.0 / float64(embeddingDim))
	for i := range emb {
		emb[i] = val
	}
	return MemoryEntry{
		ID:         id,
		NpcID:      testNpcID,
		PlayerID:   testPlayerID,
		Content:    content,
		EventType:  "test",
		Importance: importance,
		CreatedAt:  time.Now().Add(-age),
		Embedding:  emb,
	}
}

// TestRecallEmptyStore 验证空存储下 Recall 返回 nil 而非 error。
func TestRecallEmptyStore(t *testing.T) {
	store := NewFakeVectorStore()
	r := NewRetriever(store)

	query := make([]float32, embeddingDim)
	result, err := r.Recall(testNpcID, testPlayerID, query, 5)
	assert.NoError(t, err)
	assert.Nil(t, result)
}

// TestSingleInsertRecall 验证插入一条记忆后能被正确召回。
func TestSingleInsertRecall(t *testing.T) {
	store := NewFakeVectorStore()
	r := NewRetriever(store)

	entry := makeEntry("m1", "玩家首次与长老对话", 0.8, time.Hour)
	require.NoError(t, store.Upsert(entry))

	query := make([]float32, embeddingDim)
	result, err := r.Recall(testNpcID, testPlayerID, query, 5)
	assert.NoError(t, err)
	assert.Len(t, result, 1)
	assert.Equal(t, "m1", result[0].ID)
	assert.Equal(t, "玩家首次与长老对话", result[0].Content)
}

// TestTopKTruncation 验证 topK 截断：插入 10 条，只返回指定数量。
func TestTopKTruncation(t *testing.T) {
	store := NewFakeVectorStore()
	r := NewRetriever(store)

	for i := 0; i < 10; i++ {
		e := makeEntry(fmt.Sprintf("m%d", i), fmt.Sprintf("记忆%d", i), 0.5, time.Duration(i)*time.Hour)
		require.NoError(t, store.Upsert(e))
	}

	query := make([]float32, embeddingDim)
	result, err := r.Recall(testNpcID, testPlayerID, query, 3)
	assert.NoError(t, err)
	assert.Len(t, result, 3)
}

// TestImportanceWeighting 验证高重要度记忆排名高于低重要度记忆
// （在向量相似度相同的情况下）。
func TestImportanceWeighting(t *testing.T) {
	store := NewFakeVectorStore()
	r := NewRetriever(store)

	// 两条记忆年龄相同，向量相同，仅重要度不同
	lowImp := makeEntry("low", "普通对话", 0.1, time.Hour)
	highImp := makeEntry("high", "关键秘密揭露", 0.9, time.Hour)

	require.NoError(t, store.Upsert(lowImp))
	require.NoError(t, store.Upsert(highImp))

	query := make([]float32, embeddingDim)
	result, err := r.Recall(testNpcID, testPlayerID, query, 2)
	assert.NoError(t, err)
	require.Len(t, result, 2)
	// 高重要度应排第一
	assert.Equal(t, "high", result[0].ID)
}

// TestTimeDecayFavorsRecent 验证同等条件下，更新的记忆排名更靠前。
func TestTimeDecayFavorsRecent(t *testing.T) {
	store := NewFakeVectorStore()
	r := NewRetriever(store)

	// 两条记忆重要度相同、向量相同，仅时间不同
	oldEntry := makeEntry("old", "30天前的对话", 0.5, 30*24*time.Hour)
	newEntry := makeEntry("new", "1小时前的对话", 0.5, time.Hour)

	require.NoError(t, store.Upsert(oldEntry))
	require.NoError(t, store.Upsert(newEntry))

	query := make([]float32, embeddingDim)
	result, err := r.Recall(testNpcID, testPlayerID, query, 2)
	assert.NoError(t, err)
	require.Len(t, result, 2)
	// 更新的记忆应排第一
	assert.Equal(t, "new", result[0].ID)
}
