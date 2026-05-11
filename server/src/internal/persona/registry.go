// Package persona — NPC 人格注册表，支持并发安全的注册与查询。
package persona

import (
	"fmt"
	"sync"
)

// Registry 维护内存中 npc_id → Persona 的映射。
// 适合启动时批量加载、运行时偶发注册（GM 热注入）的使用模式。
// 所有方法均并发安全。
type Registry struct {
	mu    sync.RWMutex
	store map[int64]*Persona
}

// NewRegistry 创建空 Registry。
func NewRegistry() *Registry {
	return &Registry{store: make(map[int64]*Persona)}
}

// Register 注册或覆盖指定 NPC 的人格蓝图。
// p 不可为 nil，且 p.ID 必须与传入 npcID 一致；违反时返回 error。
func (r *Registry) Register(npcID int64, p *Persona) error {
	if p == nil {
		return fmt.Errorf("persona: Register(%d): persona must not be nil", npcID)
	}
	if p.ID != npcID {
		return fmt.Errorf("persona: Register(%d): persona.ID mismatch (got %d)", npcID, p.ID)
	}

	r.mu.Lock()
	r.store[npcID] = p
	r.mu.Unlock()
	return nil
}

// Get 按 npc_id 查询人格蓝图。
// 不存在时返回 nil, nil（不视为错误，调用方决定降级行为）。
func (r *Registry) Get(npcID int64) (*Persona, error) {
	r.mu.RLock()
	p := r.store[npcID]
	r.mu.RUnlock()
	return p, nil
}

// All 返回当前所有已注册 Persona 的快照切片（无序）。
// 快照与内部 store 独立，调用方可安全遍历。
func (r *Registry) All() []*Persona {
	r.mu.RLock()
	defer r.mu.RUnlock()

	out := make([]*Persona, 0, len(r.store))
	for _, p := range r.store {
		out = append(out, p)
	}
	return out
}

// Len 返回当前注册数量，用于健康检查和监控。
func (r *Registry) Len() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.store)
}

// Registry 同时实现 Loader 接口，可直接传给 LuaBridge。
var _ Loader = (*Registry)(nil)

// Load 实现 Loader 接口，委托给 Get。
func (r *Registry) Load(id int64) (*Persona, error) {
	return r.Get(id)
}
