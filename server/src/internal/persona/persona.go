// Package persona 定义 NPC 人格层数据结构和 Lua 桥接 stub。
//
// 设计意图：
//   - Persona 是 NPC 的静态人格蓝图，从 JSON/TOML 配置加载，不随状态变化。
//   - Loader 接口隔离存储细节（文件、DB、内存），方便测试替换。
//   - LuaBridge 将 Persona 序列化为 Lua 表，供 npc_*.lua 脚本读取五要素。
//   - 本包不引入任何数据库依赖；数据层实现由调用方注入。
package persona

import (
	lua "github.com/yuin/gopher-lua"
)

// Persona 描述一个 NPC 的完整人格蓝图。
// 字段全部为值语义，便于并发只读访问。
type Persona struct {
	// ID 对应 NPC 模板 ID，与游戏数据 XML 中 npc_id 保持一致。
	ID int64 `json:"id"`

	// Name NPC 显示名称，中文 UTF-8。
	Name string `json:"name"`

	// Archetype 人格原型标签，如 "wise_elder"、"corrupt_merchant"。
	Archetype string `json:"archetype"`

	// Identity 自我定位（五要素之一）：NPC 如何定义自己。
	Identity string `json:"identity"`

	// Desire 核心欲望（五要素之一）：NPC 最深切的追求。
	Desire string `json:"desire"`

	// Fear 核心恐惧（五要素之一）：NPC 最不愿面对的事物。
	Fear string `json:"fear"`

	// Secret 隐藏秘密（五要素之一）：玩家可通过特定行为触发揭露。
	Secret string `json:"secret"`

	// Skills NPC 技能标签列表（五要素之一），影响对话和事件响应。
	Skills []string `json:"skills"`

	// LoraPath 对应 Stable Diffusion LoRA 权重路径（Vision 层用），
	// 空字符串表示使用默认模型。
	LoraPath string `json:"lora_path,omitempty"`

	// VoiceID 对应 TTS 音色 ID（Voice 层用），0 表示无语音。
	VoiceID int64 `json:"voice_id,omitempty"`

	// Traits 扩展特征键值对，供 Director 层读取，
	// 例如 {"faction":"elyos","alignment":"lawful_good"}。
	Traits map[string]any `json:"traits,omitempty"`
}

// Loader 从任意数据源加载 Persona 的接口。
// 实现方可以是文件、DB、内存缓存；测试时用 fake 实现。
type Loader interface {
	// Load 按 NPC 模板 ID 加载人格蓝图。
	// 找不到时返回 nil, nil；内部错误返回 err。
	Load(id int64) (*Persona, error)
}

// LuaBridge 将 Persona 序列化为 gopher-lua 表，供 Lua 脚本直接访问。
// 与 luahost.Bridge 解耦：仅依赖 gopher-lua，不引入 VMPool。
type LuaBridge struct {
	loader Loader
}

// NewLuaBridge 创建绑定到指定 Loader 的桥接实例。
func NewLuaBridge(l Loader) *LuaBridge {
	return &LuaBridge{loader: l}
}

// ToLuaTable 将指定 NPC ID 的 Persona 转换为 lua.LTable。
// 返回表结构：{ id, name, archetype, identity, desire, fear, secret, skills[], lora_path, voice_id, traits{} }
// 找不到时返回 lua.LNil。
func (b *LuaBridge) ToLuaTable(L *lua.LState, npcID int64) lua.LValue {
	p, err := b.loader.Load(npcID)
	if err != nil || p == nil {
		return lua.LNil
	}

	t := L.NewTable()
	L.SetField(t, "id", lua.LNumber(p.ID))
	L.SetField(t, "name", lua.LString(p.Name))
	L.SetField(t, "archetype", lua.LString(p.Archetype))
	L.SetField(t, "identity", lua.LString(p.Identity))
	L.SetField(t, "desire", lua.LString(p.Desire))
	L.SetField(t, "fear", lua.LString(p.Fear))
	L.SetField(t, "secret", lua.LString(p.Secret))

	// skills 转为 Lua 数组（1-indexed）
	skills := L.NewTable()
	for i, s := range p.Skills {
		skills.RawSetInt(i+1, lua.LString(s))
	}
	L.SetField(t, "skills", skills)

	L.SetField(t, "lora_path", lua.LString(p.LoraPath))
	L.SetField(t, "voice_id", lua.LNumber(p.VoiceID))

	// traits 转为 Lua 哈希表
	traits := L.NewTable()
	for k, v := range p.Traits {
		switch val := v.(type) {
		case string:
			L.SetField(traits, k, lua.LString(val))
		case float64:
			L.SetField(traits, k, lua.LNumber(val))
		case bool:
			if val {
				L.SetField(traits, k, lua.LTrue)
			} else {
				L.SetField(traits, k, lua.LFalse)
			}
		default:
			L.SetField(traits, k, lua.LString(""))
		}
	}
	L.SetField(t, "traits", traits)

	return t
}
