// Package director 实现 M5 世界智能导演（World Intelligence Plane）。
// 每 60 秒触发一次 Tick，根据世界状态由 LLM 编排层生成 DirectorAction 列表并写回 NATS。
package director

import "time"

// PlayerSnapshot 玩家快照，包含位置、等级、状态等核心字段。
type PlayerSnapshot struct {
	PlayerID  int64   `json:"player_id"`  // 玩家唯一 ID
	Name      string  `json:"name"`       // 角色名
	Level     int     `json:"level"`      // 等级
	ZoneID    int32   `json:"zone_id"`    // 当前区域
	X         float32 `json:"x"`          // X 坐标
	Y         float32 `json:"y"`          // Y 坐标
	Z         float32 `json:"z"`          // Z 坐标
	IsOnline  bool    `json:"is_online"`  // 是否在线
}

// NpcSnapshot NPC 快照，包含 AI 状态与巡逻信息。
type NpcSnapshot struct {
	NpcID     int64   `json:"npc_id"`    // NPC 唯一 ID
	TemplateID int32  `json:"template_id"` // NPC 模板 ID
	Name      string  `json:"name"`      // NPC 名称
	ZoneID    int32   `json:"zone_id"`   // 所在区域
	X         float32 `json:"x"`         // X 坐标
	Y         float32 `json:"y"`         // Y 坐标
	Z         float32 `json:"z"`         // Z 坐标
	IsIdle    bool    `json:"is_idle"`   // 是否处于空闲状态
	HP        int32   `json:"hp"`        // 当前血量
	MaxHP     int32   `json:"max_hp"`    // 最大血量
}

// EventSnapshot 当前活跃世界事件快照。
type EventSnapshot struct {
	EventID   string `json:"event_id"`  // 事件唯一标识（UUID）
	EventType string `json:"event_type"` // 事件类型（如 "boss_spawn", "weather_change"）
	ZoneID    int32  `json:"zone_id"`   // 事件区域
	StartsAt  time.Time `json:"starts_at"` // 事件开始时间
	ExpiresAt time.Time `json:"expires_at"` // 事件过期时间
	Active    bool   `json:"active"`    // 是否仍活跃
}

// WorldState 世界状态快照，Director Tick 的唯一输入。
// 通过 NATS subject "world.state.snapshot" 拉取。
type WorldState struct {
	Players  []PlayerSnapshot  `json:"players"`  // 所有在线玩家
	Npcs     []NpcSnapshot     `json:"npcs"`     // 活跃 NPC 列表
	Events   []EventSnapshot   `json:"events"`   // 当前世界事件
	Now      time.Time         `json:"now"`      // 快照时间戳
}
