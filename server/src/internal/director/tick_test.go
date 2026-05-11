package director

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mockOrchestrator 用于测试的 LLM 编排器 mock。
type mockOrchestrator struct {
	// actions 固定返回的动作列表
	actions []DirectorAction
	// err 固定返回的错误（nil 表示无错）
	err error
}

// Orchestrate 实现 LLMOrchestrator 接口。
func (m *mockOrchestrator) Orchestrate(_ context.Context, _ WorldState) ([]DirectorAction, error) {
	return m.actions, m.err
}

// emptyState 辅助函数：返回完全空的世界状态。
func emptyState() WorldState {
	return WorldState{Now: time.Now()}
}

// densePlayerState 辅助函数：5 名在线玩家聚集在同一区域，无活跃事件。
func densePlayerState() WorldState {
	players := make([]PlayerSnapshot, 5)
	for i := range players {
		players[i] = PlayerSnapshot{
			PlayerID: int64(10001 + i),
			Name:     "测试玩家",
			Level:    55,
			ZoneID:   210010,
			IsOnline: true,
		}
	}
	return WorldState{
		Players: players,
		Now:     time.Now(),
	}
}

// idleNpcState 辅助函数：包含 4 个空闲 NPC 的世界状态（触发 MoveNPC 启发式）。
func idleNpcState() WorldState {
	npcs := []NpcSnapshot{
		{NpcID: 50001, Name: "晨曦长老", ZoneID: 210010, IsIdle: true, HP: 5000, MaxHP: 5000},
		{NpcID: 50002, Name: "铁甲哨兵", ZoneID: 210010, IsIdle: true, HP: 2000, MaxHP: 2000},
		{NpcID: 50003, Name: "暗影斥候", ZoneID: 210010, IsIdle: true, HP: 1800, MaxHP: 1800},
		{NpcID: 50004, Name: "圣光护卫", ZoneID: 210010, IsIdle: true, HP: 3000, MaxHP: 3000},
	}
	return WorldState{
		Players: []PlayerSnapshot{
			{PlayerID: 10001, Name: "单人玩家", Level: 40, ZoneID: 210010, IsOnline: true},
		},
		Npcs: npcs,
		Now:  time.Now(),
	}
}

// criticalEventState 辅助函数：高等级玩家集中 + LLM 注入任务触发条件。
func criticalEventState() WorldState {
	return WorldState{
		Players: []PlayerSnapshot{
			{PlayerID: 10001, Name: "晨曦战士", Level: 60, ZoneID: 210010, IsOnline: true},
			{PlayerID: 10002, Name: "暮光法师", Level: 58, ZoneID: 210010, IsOnline: true},
		},
		Now: time.Now(),
	}
}

// TestDecideTick_EmptyState 测试：完全空的世界状态应返回 0 个动作，不调用 LLM。
func TestDecideTick_EmptyState(t *testing.T) {
	mock := &mockOrchestrator{actions: []DirectorAction{
		SpawnEvent{ZoneID: 1, TemplateID: 100, Count: 1},
	}}
	engine := NewTickEngine(mock)

	actions, err := engine.DecideTick(context.Background(), emptyState())

	require.NoError(t, err)
	// 空状态应直接返回 nil，不触发 LLM
	assert.Empty(t, actions, "空世界状态不应产生任何动作")
}

// TestDecideTick_HighPlayerDensity 测试：高玩家密度且无活跃事件 → 触发 SpawnEvent + 天气变化。
func TestDecideTick_HighPlayerDensity(t *testing.T) {
	// LLM mock 返回 ChangeWeather
	mock := &mockOrchestrator{actions: []DirectorAction{
		ChangeWeather{ZoneID: 210010, WeatherType: "storm", Intensity: 0.8, DurationSec: 300},
	}}
	engine := NewTickEngine(mock)

	actions, err := engine.DecideTick(context.Background(), densePlayerState())

	require.NoError(t, err)
	require.NotEmpty(t, actions, "高玩家密度应至少产生 1 个动作")

	// 验证包含 SpawnEvent（来自启发式）
	hasSpawn := false
	hasWeather := false
	for _, a := range actions {
		switch a.ActionType() {
		case "spawn_event":
			hasSpawn = true
		case "change_weather":
			hasWeather = true
		}
	}
	assert.True(t, hasSpawn, "启发式规则应产生 SpawnEvent")
	assert.True(t, hasWeather, "LLM 应补充 ChangeWeather")
}

// TestDecideTick_IdleNPC 测试：大量空闲 NPC → 触发 MoveNPC 动作。
func TestDecideTick_IdleNPC(t *testing.T) {
	mock := &mockOrchestrator{} // LLM 无额外动作
	engine := NewTickEngine(mock)

	actions, err := engine.DecideTick(context.Background(), idleNpcState())

	require.NoError(t, err)
	hasMoveNPC := false
	for _, a := range actions {
		if a.ActionType() == "move_npc" {
			hasMoveNPC = true
			break
		}
	}
	assert.True(t, hasMoveNPC, "空闲 NPC 超 3 个时应触发 MoveNPC")
}

// TestDecideTick_CriticalEvent 测试：关键事件（高等级玩家聚集）→ LLM 注入任务。
func TestDecideTick_CriticalEvent(t *testing.T) {
	mock := &mockOrchestrator{actions: []DirectorAction{
		InjectQuest{QuestTemplateID: 30501, ZoneID: 210010, ExpiryMinutes: 30},
	}}
	engine := NewTickEngine(mock)

	actions, err := engine.DecideTick(context.Background(), criticalEventState())

	require.NoError(t, err)
	hasQuest := false
	for _, a := range actions {
		if a.ActionType() == "inject_quest" {
			hasQuest = true
			break
		}
	}
	assert.True(t, hasQuest, "关键事件应触发 InjectQuest")
}

// TestDecideTick_ConcurrentApply 测试：并发执行多个 Apply 不会竞争或 panic。
func TestDecideTick_ConcurrentApply(t *testing.T) {
	// 构造包含全部 4 种 action 的结果
	mock := &mockOrchestrator{actions: []DirectorAction{
		SpawnEvent{ZoneID: 210010, TemplateID: 700901, Count: 2, EventTag: "concurrent_test"},
		ChangeWeather{ZoneID: 210010, WeatherType: "rain", Intensity: 0.5, DurationSec: 120},
		MoveNPC{NpcID: 50001, TargetX: 1300, TargetY: 200, TargetZ: 800, PatrolMode: "guard"},
		InjectQuest{QuestTemplateID: 30502, ZoneID: 210010, ExpiryMinutes: 15},
	}}
	engine := NewTickEngine(mock)

	// 并发执行 10 次 DecideTick
	const goroutines = 10
	done := make(chan struct{}, goroutines)
	for i := 0; i < goroutines; i++ {
		go func() {
			defer func() { done <- struct{}{} }()
			actions, err := engine.DecideTick(context.Background(), densePlayerState())
			assert.NoError(t, err)
			// 并发 Apply
			ctx := context.Background()
			for _, a := range actions {
				assert.NoError(t, a.Apply(ctx))
			}
		}()
	}
	for i := 0; i < goroutines; i++ {
		select {
		case <-done:
		case <-time.After(5 * time.Second):
			t.Fatal("并发 Apply 超时，可能存在死锁")
		}
	}
}
