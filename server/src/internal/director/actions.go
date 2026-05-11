package director

import "context"

// DirectorAction 导演动作接口。所有世界干预行为必须实现此接口。
// Apply 方法在实际连接 NATS/World 时执行；Describe 用于日志与 LLM 反馈。
type DirectorAction interface {
	// Apply 将动作写入下游（stub：打印日志，真实版写 NATS）。
	Apply(ctx context.Context) error
	// Describe 返回动作的人类可读描述，用于日志和 LLM 上下文反馈。
	Describe() string
	// ActionType 返回动作类型标识符（如 "spawn_event"）。
	ActionType() string
}

// SpawnEvent 在指定区域生成怪物、NPC 或世界事件。
// 对应 NATS subject: "director.action.spawn"
type SpawnEvent struct {
	ZoneID     int32  `json:"zone_id"`    // 目标区域
	TemplateID int32  `json:"template_id"` // NPC/怪物模板 ID
	Count      int    `json:"count"`      // 生成数量
	EventTag   string `json:"event_tag"`  // 标记（如 "elite_raid"）
}

// Apply 执行生成事件（stub 实现，真实版发布至 NATS）。
func (a SpawnEvent) Apply(_ context.Context) error {
	// TODO: nats.Publish("director.action.spawn", marshal(a))
	return nil
}

// Describe 返回动作描述。
func (a SpawnEvent) Describe() string {
	return "spawn_event zone=" + itoa(a.ZoneID) + " template=" + itoa32(a.TemplateID) +
		" count=" + itoaInt(a.Count) + " tag=" + a.EventTag
}

// ActionType 返回动作类型。
func (a SpawnEvent) ActionType() string { return "spawn_event" }

// ChangeWeather 改变区域天气、光照或季节参数。
// 对应 NATS subject: "director.action.weather"
type ChangeWeather struct {
	ZoneID      int32   `json:"zone_id"`      // 目标区域（0 = 全服）
	WeatherType string  `json:"weather_type"` // 天气类型（"rain", "fog", "storm", "clear"）
	Intensity   float32 `json:"intensity"`    // 强度（0.0-1.0）
	DurationSec int     `json:"duration_sec"` // 持续时长（秒）
}

// Apply 执行天气变化（stub）。
func (a ChangeWeather) Apply(_ context.Context) error {
	// TODO: nats.Publish("director.action.weather", marshal(a))
	return nil
}

// Describe 返回动作描述。
func (a ChangeWeather) Describe() string {
	return "change_weather zone=" + itoa(a.ZoneID) + " type=" + a.WeatherType
}

// ActionType 返回动作类型。
func (a ChangeWeather) ActionType() string { return "change_weather" }

// MoveNPC 调整 NPC 的巡逻路径或目的地。
// 对应 NATS subject: "director.action.move_npc"
type MoveNPC struct {
	NpcID      int64   `json:"npc_id"`     // 目标 NPC ID
	TargetX    float32 `json:"target_x"`   // 目标 X 坐标
	TargetY    float32 `json:"target_y"`   // 目标 Y 坐标
	TargetZ    float32 `json:"target_z"`   // 目标 Z 坐标
	PatrolMode string  `json:"patrol_mode"` // 巡逻模式（"wander", "follow_player", "guard"）
}

// Apply 执行 NPC 移动（stub）。
func (a MoveNPC) Apply(_ context.Context) error {
	// TODO: nats.Publish("director.action.move_npc", marshal(a))
	return nil
}

// Describe 返回动作描述。
func (a MoveNPC) Describe() string {
	return "move_npc id=" + itoa64(a.NpcID) + " mode=" + a.PatrolMode
}

// ActionType 返回动作类型。
func (a MoveNPC) ActionType() string { return "move_npc" }

// InjectQuest 向指定玩家或全区域动态注入任务。
// 对应 NATS subject: "director.action.inject_quest"
type InjectQuest struct {
	QuestTemplateID int32   `json:"quest_template_id"` // 任务模板 ID
	TargetPlayerIDs []int64 `json:"target_player_ids"` // 目标玩家列表（空 = 全区域广播）
	ZoneID          int32   `json:"zone_id"`           // 广播区域（仅 TargetPlayerIDs 为空时生效）
	ExpiryMinutes   int     `json:"expiry_minutes"`    // 限时任务过期分钟数（0 = 无限制）
}

// Apply 执行任务注入（stub）。
func (a InjectQuest) Apply(_ context.Context) error {
	// TODO: nats.Publish("director.action.inject_quest", marshal(a))
	return nil
}

// Describe 返回动作描述。
func (a InjectQuest) Describe() string {
	return "inject_quest template=" + itoa32(a.QuestTemplateID) +
		" zone=" + itoa(a.ZoneID) + " targets=" + itoaInt(len(a.TargetPlayerIDs))
}

// ActionType 返回动作类型。
func (a InjectQuest) ActionType() string { return "inject_quest" }

// — 内部辅助（避免引入 fmt 包，保持零依赖）—

func itoa(n int32) string   { return itoaInt(int(n)) }
func itoa32(n int32) string { return itoaInt(int(n)) }
func itoa64(n int64) string { return itoaInt(int(n)) }

func itoaInt(n int) string {
	if n == 0 {
		return "0"
	}
	neg := false
	if n < 0 {
		neg = true
		n = -n
	}
	buf := [20]byte{}
	pos := len(buf)
	for n > 0 {
		pos--
		buf[pos] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		pos--
		buf[pos] = '-'
	}
	return string(buf[pos:])
}
