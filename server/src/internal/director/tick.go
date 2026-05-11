package director

import "context"

// LLMOrchestrator LLM 编排器接口，供 TickEngine 调用。
// 真实实现对接 OpenRouter Bridge（:8520）；测试中注入 mock。
type LLMOrchestrator interface {
	// Orchestrate 接收世界状态，返回建议的 DirectorAction 列表。
	// ctx 携带超时控制；state 是当前世界快照。
	Orchestrate(ctx context.Context, state WorldState) ([]DirectorAction, error)
}

// TickEngine 世界导演核心引擎。
// 通过依赖注入接收 LLMOrchestrator，保持纯逻辑可测性。
type TickEngine struct {
	llm LLMOrchestrator // LLM 编排器（可 mock）
}

// NewTickEngine 创建 TickEngine 实例。
// llm 必须非 nil；调用方负责传入合适的实现（生产/测试）。
func NewTickEngine(llm LLMOrchestrator) *TickEngine {
	if llm == nil {
		panic("director: LLMOrchestrator must not be nil")
	}
	return &TickEngine{llm: llm}
}

// DecideTick 根据世界状态决策本次 Tick 要执行的动作列表。
// 先做本地启发式判断（快速路径），再调 LLM 做深度编排。
// 空状态（无玩家、无 NPC、无事件）时直接返回空切片，不调 LLM。
func (e *TickEngine) DecideTick(ctx context.Context, state WorldState) ([]DirectorAction, error) {
	// 快速路径：世界完全空闲，跳过 LLM 调用节省费用
	if len(state.Players) == 0 && len(state.Npcs) == 0 && len(state.Events) == 0 {
		return nil, nil
	}

	// 本地启发式：高密度玩家区域直接追加天气事件，减少 LLM 调用频次
	actions := e.heuristicActions(state)

	// 调 LLM 做深度编排（可能追加更多 action）
	llmActions, err := e.llm.Orchestrate(ctx, state)
	if err != nil {
		// LLM 失败不阻断 Tick：退化为纯启发式结果，记录错误由 main 层处理
		return actions, err
	}
	actions = append(actions, llmActions...)
	return actions, nil
}

// heuristicActions 本地规则引擎：快速、廉价、无 LLM 调用。
// 规则：玩家密度超阈值 → 触发生成事件；存在大量空闲 NPC → 触发巡逻调整。
func (e *TickEngine) heuristicActions(state WorldState) []DirectorAction {
	var actions []DirectorAction

	// 规则 1：在线玩家 ≥5 且当前无活跃事件 → 生成精英怪物事件
	if len(state.Players) >= 5 && activeEventCount(state) == 0 {
		actions = append(actions, SpawnEvent{
			ZoneID:     210010, // 晨曦森林区域
			TemplateID: 700901, // 精英哨兵模板
			Count:      3,
			EventTag:   "heuristic_elite",
		})
	}

	// 规则 2：空闲 NPC 超过 3 个 → 调整其中一个的巡逻模式
	idleNpcs := idleNpcList(state)
	if len(idleNpcs) > 3 {
		npc := idleNpcs[0]
		actions = append(actions, MoveNPC{
			NpcID:      npc.NpcID,
			TargetX:    npc.X + 50,
			TargetY:    npc.Y,
			TargetZ:    npc.Z,
			PatrolMode: "wander",
		})
	}

	return actions
}

// activeEventCount 统计当前活跃事件数量。
func activeEventCount(state WorldState) int {
	count := 0
	for _, ev := range state.Events {
		if ev.Active {
			count++
		}
	}
	return count
}

// idleNpcList 返回所有处于空闲状态的 NPC。
func idleNpcList(state WorldState) []NpcSnapshot {
	var idle []NpcSnapshot
	for _, npc := range state.Npcs {
		if npc.IsIdle {
			idle = append(idle, npc)
		}
	}
	return idle
}
