package persona

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	lua "github.com/yuin/gopher-lua"
)

// 测试数据：晨曦村长老砚秋
var elderPersona = &Persona{
	ID:        900001,
	Name:      "晨曦村长老 砚秋",
	Archetype: "wise_elder",
	Identity:  "晨曦村守护者",
	Desire:    "重见已故妻子",
	Fear:      "再次失去亲人",
	Secret:    "知道地脉裂缝真相",
	Skills:    []string{"治愈术", "古辞", "观星"},
	Traits:    map[string]any{"faction": "elyos", "level_req": float64(1)},
}

// TestGetNilPersona 验证查询不存在的 NPC 时返回 nil 而非 error。
func TestGetNilPersona(t *testing.T) {
	r := NewRegistry()
	p, err := r.Get(99999)
	assert.NoError(t, err)
	assert.Nil(t, p)
}

// TestMissingIDReturnsNil 验证 LuaBridge.ToLuaTable 对不存在 NPC 返回 LNil。
func TestMissingIDReturnsNil(t *testing.T) {
	r := NewRegistry()
	bridge := NewLuaBridge(r)
	L := lua.NewState()
	defer L.Close()

	result := bridge.ToLuaTable(L, 99999)
	assert.Equal(t, lua.LNil, result)
}

// TestRoundTripSerialization 验证 Register 后 Get 能取回相同数据。
func TestRoundTripSerialization(t *testing.T) {
	r := NewRegistry()
	assert.NoError(t, r.Register(elderPersona.ID, elderPersona))

	got, err := r.Get(elderPersona.ID)
	assert.NoError(t, err)
	assert.Equal(t, elderPersona, got)
	assert.Equal(t, 1, r.Len())
}

// TestLuaBridgeFields 验证 ToLuaTable 正确填充所有字段。
func TestLuaBridgeFields(t *testing.T) {
	r := NewRegistry()
	assert.NoError(t, r.Register(elderPersona.ID, elderPersona))

	bridge := NewLuaBridge(r)
	L := lua.NewState()
	defer L.Close()

	val := bridge.ToLuaTable(L, elderPersona.ID)
	tbl, ok := val.(*lua.LTable)
	assert.True(t, ok, "应返回 *lua.LTable")

	assert.Equal(t, lua.LNumber(900001), tbl.RawGetString("id"))
	assert.Equal(t, lua.LString("晨曦村长老 砚秋"), tbl.RawGetString("name"))
	assert.Equal(t, lua.LString("知道地脉裂缝真相"), tbl.RawGetString("secret"))

	// 验证 skills 数组长度
	skillsTbl, ok := tbl.RawGetString("skills").(*lua.LTable)
	assert.True(t, ok)
	assert.Equal(t, 3, skillsTbl.Len())

	// 验证 traits 字段
	traitsTbl, ok := tbl.RawGetString("traits").(*lua.LTable)
	assert.True(t, ok)
	assert.Equal(t, lua.LString("elyos"), traitsTbl.RawGetString("faction"))
}

// TestConcurrentGetRegister 验证并发 Register + Get 无数据竞争。
func TestConcurrentGetRegister(t *testing.T) {
	r := NewRegistry()
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines * 2)

	// 并发 Register（不同 ID 避免 ID 校验失败）
	for i := 0; i < goroutines; i++ {
		id := int64(i + 1)
		p := &Persona{ID: id, Name: "npc", Archetype: "test"}
		go func() {
			defer wg.Done()
			_ = r.Register(id, p)
		}()
	}

	// 并发 Get（可能返回 nil，不视为错误）
	for i := 0; i < goroutines; i++ {
		id := int64(i + 1)
		go func() {
			defer wg.Done()
			_, _ = r.Get(id)
		}()
	}

	wg.Wait()
	// 注册数量 ≤ goroutines（部分写入可能被覆盖但不会 panic）
	assert.LessOrEqual(t, r.Len(), goroutines)
}
