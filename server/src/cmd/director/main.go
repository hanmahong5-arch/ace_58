// director 是 M5 World Intelligence Plane 的独立可执行服务。
// 每 60 秒触发一次 World Tick：
//   1. 从 NATS 拉取世界状态快照（stub）
//   2. 调用 LLM 编排器决策 DirectorAction 列表（stub interface）
//   3. 将 DirectorAction 逐条 Apply 到 NATS（stub）
//
// 支持 context 传播的 graceful shutdown：收到 SIGINT/SIGTERM 后
// 等待当前 Tick 完成再退出，保证动作原子性。
package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"aion58/internal/director"
)

// stubNATSPuller NATS 状态拉取 stub。真实版订阅 "world.state.snapshot"。
func stubNATSPuller() director.WorldState {
	return director.WorldState{
		Now: time.Now(),
		Players: []director.PlayerSnapshot{
			{PlayerID: 10001, Name: "晨曦战士", Level: 55, ZoneID: 210010, X: 1234.5, Y: 200.0, Z: 789.1, IsOnline: true},
			{PlayerID: 10002, Name: "暮光法师", Level: 52, ZoneID: 210010, X: 1300.0, Y: 200.0, Z: 800.0, IsOnline: true},
			{PlayerID: 10003, Name: "星辰猎手", Level: 60, ZoneID: 220020, X: 500.0, Y: 180.0, Z: 400.0, IsOnline: true},
			{PlayerID: 10004, Name: "碎月刺客", Level: 58, ZoneID: 210010, X: 1250.0, Y: 200.0, Z: 780.0, IsOnline: true},
			{PlayerID: 10005, Name: "霜翼使者", Level: 50, ZoneID: 210010, X: 1260.0, Y: 195.0, Z: 770.0, IsOnline: true},
		},
		Npcs: []director.NpcSnapshot{
			{NpcID: 50001, TemplateID: 200301, Name: "晨曦长老", ZoneID: 210010, X: 1100.0, Y: 200.0, Z: 700.0, IsIdle: false, HP: 5000, MaxHP: 5000},
			{NpcID: 50002, TemplateID: 200302, Name: "铁甲哨兵", ZoneID: 210010, X: 1200.0, Y: 200.0, Z: 750.0, IsIdle: true, HP: 2000, MaxHP: 2000},
			{NpcID: 50003, TemplateID: 200303, Name: "暗影斥候", ZoneID: 210010, X: 1350.0, Y: 200.0, Z: 820.0, IsIdle: true, HP: 1800, MaxHP: 1800},
			{NpcID: 50004, TemplateID: 200304, Name: "圣光护卫", ZoneID: 220020, X: 480.0, Y: 180.0, Z: 390.0, IsIdle: true, HP: 3000, MaxHP: 3000},
			{NpcID: 50005, TemplateID: 200305, Name: "深渊守门人", ZoneID: 230030, X: 200.0, Y: 100.0, Z: 200.0, IsIdle: true, HP: 8000, MaxHP: 10000},
		},
		Events: []director.EventSnapshot{},
	}
}

// stubNATSPublisher 将 actions 写回 NATS（stub：序列化后打印到日志）。
// 真实版：nats.Publish("director.actions", payload)
func stubNATSPublisher(actions []director.DirectorAction) {
	for _, a := range actions {
		slog.Info("director: action queued",
			"type", a.ActionType(),
			"desc", a.Describe(),
		)
	}
}

// stubLLMOrchestrator LLM 编排器 stub，满足 director.LLMOrchestrator 接口。
// 真实版调用 OpenRouter Bridge :8520。
type stubLLMOrchestrator struct{}

// Orchestrate 根据世界状态返回 mock LLM 建议动作。
func (s *stubLLMOrchestrator) Orchestrate(_ context.Context, state director.WorldState) ([]director.DirectorAction, error) {
	var actions []director.DirectorAction

	// mock：如果有关键事件（高等级玩家集中在某区域），注入任务
	highLevelCount := 0
	var zoneID int32 = 210010
	for _, p := range state.Players {
		if p.Level >= 55 && p.ZoneID == zoneID {
			highLevelCount++
		}
	}
	if highLevelCount >= 2 {
		actions = append(actions, director.InjectQuest{
			QuestTemplateID: 30501,
			ZoneID:          zoneID,
			ExpiryMinutes:   30,
		})
		actions = append(actions, director.ChangeWeather{
			ZoneID:      zoneID,
			WeatherType: "storm",
			Intensity:   0.7,
			DurationSec: 300,
		})
	}

	return actions, nil
}

// runTick 执行一次完整的 World Tick。
// 返回非 nil error 时 main 循环打印警告但不退出。
func runTick(ctx context.Context, engine *director.TickEngine) error {
	// 1. 拉取世界状态
	state := stubNATSPuller()

	tickCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// 2. 决策动作列表
	actions, err := engine.DecideTick(tickCtx, state)
	if err != nil {
		slog.Warn("director: LLM orchestration degraded", "err", err)
		// 不 return：启发式结果仍可用
	}

	if len(actions) == 0 {
		slog.Debug("director: tick produced no actions", "players", len(state.Players))
		return nil
	}

	// 3. Apply 所有动作（并发安全：各 action 独立）
	for _, a := range actions {
		if applyErr := a.Apply(tickCtx); applyErr != nil {
			slog.Error("director: action apply failed", "type", a.ActionType(), "err", applyErr)
		}
	}

	// 4. 写回 NATS
	stubNATSPublisher(actions)

	if b, _ := json.Marshal(map[string]any{
		"tick_time":    state.Now,
		"action_count": len(actions),
	}); b != nil {
		slog.Info("director: tick complete", "summary", string(b))
	}

	return nil
}

func main() {
	// 结构化日志，便于 logd 服务解析
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})))

	slog.Info("director: starting M5 World Intelligence Plane",
		"tick_interval_sec", 60,
		"version", "0.1.0",
	)

	// 根 context + signal 注册
	rootCtx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	engine := director.NewTickEngine(&stubLLMOrchestrator{})

	ticker := time.NewTicker(60 * time.Second)
	defer ticker.Stop()

	// 立即执行第一次 Tick，不必等待 60s
	if err := runTick(rootCtx, engine); err != nil {
		slog.Error("director: initial tick error", "err", err)
	}

	for {
		select {
		case <-ticker.C:
			if err := runTick(rootCtx, engine); err != nil {
				slog.Error("director: tick error", "err", err)
			}
		case <-rootCtx.Done():
			slog.Info("director: shutdown signal received, waiting for current tick to finish")
			// ticker.Stop() 已在 defer 中，直接退出
			return
		}
	}
}
