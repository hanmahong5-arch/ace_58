// Round 7 C5 — Entropy v2 Forge ID 测试。
//
// 三类合约：
//   1. 确定性: 同 spec 反复 hash 必得同 ID（Lua 表遍历无序但结果稳定）
//   2. 区分度: 1000 个不同 (item_id, count) → 0 碰撞（SHA1 截 32-bit
//      理论碰撞期望在 ~65k 输入后；1000 内必须 0）
//   3. 格式: 8 字符大写 hex
//   4. 集成: add_item_with_random_attr 流程内 entropy.forge_id 可被调用
//      且不破坏既有 SP 调用次数

package luahost

import (
	"regexp"
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// callForgeID 在 Lua 状态里调用 entropy.forge_id 并返回字符串结果。
func callForgeID(t *testing.T, L *lua.LState, specChunk string) string {
	t.Helper()
	if err := L.DoString(`__forge_test_result = entropy.forge_id(` + specChunk + `)`); err != nil {
		t.Fatalf("forge_id Lua eval: %v", err)
	}
	v := L.GetGlobal("__forge_test_result")
	s, ok := v.(lua.LString)
	if !ok {
		t.Fatalf("forge_id returned non-string %T", v)
	}
	return string(s)
}

// TestForgeIDDeterministic — 同 spec 反复求 ID 必相等。
func TestForgeIDDeterministic(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const spec = `{
		item_id = 100000001, count = 1, race = 2, season_seed = 0xC0FFEE,
		stones = {1001, 1002, 0, 0, 0, 0},
		attrs  = {
			{attr_id="phyAttack",         value=10},
			{attr_id="critical",          value=5},
			{attr_id="magicalSkillBoost", value=20},
		}
	}`
	first := callForgeID(t, L, spec)
	for i := 0; i < 5; i++ {
		again := callForgeID(t, L, spec)
		if again != first {
			t.Fatalf("non-deterministic forge ID: iter=%d first=%s now=%s",
				i, first, again)
		}
	}
	t.Logf("deterministic forge ID = %s", first)
}

// TestForgeIDFormat — 必须是 8 字符大写 hex。
func TestForgeIDFormat(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	re := regexp.MustCompile(`^[0-9A-F]{8}$`)
	for i := 0; i < 50; i++ {
		spec := `{
			item_id = ` + itoaForLua(int64(100000000+i)) + `,
			count = 1, race = 1, season_seed = 0,
			stones = {}, attrs = {},
		}`
		id := callForgeID(t, L, spec)
		if !re.MatchString(id) {
			t.Fatalf("ID %q does not match ^[0-9A-F]{8}$ (i=%d)", id, i)
		}
	}
}

// TestForgeIDCollisionRate — 1000 个不同 (item_id, count) → 期望 0 碰撞。
// SHA1 截 4 字节 = 2^32 空间，1000 输入碰撞期望约 1000^2 / 2^33 ≈ 1.2e-4。
func TestForgeIDCollisionRate(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const N = 1000
	seen := make(map[string]struct {
		iid, cnt int64
	}, N)
	collisions := 0
	for i := int64(1); i <= N; i++ {
		spec := `{
			item_id = ` + itoaForLua(100000000+i) + `,
			count   = ` + itoaForLua(i) + `,
			race    = 0, season_seed = 0,
			stones  = {}, attrs = {},
		}`
		id := callForgeID(t, L, spec)
		if prev, dup := seen[id]; dup {
			collisions++
			t.Logf("collision: ID=%s prev=(%d,%d) now=(%d,%d)",
				id, prev.iid, prev.cnt, 100000000+i, i)
		}
		seen[id] = struct{ iid, cnt int64 }{100000000 + i, i}
	}
	if collisions > 0 {
		t.Errorf("expected 0 collisions in %d samples, got %d", N, collisions)
	} else {
		t.Logf("no collisions in %d samples (uniqueness 100%%)", N)
	}
}

// TestForgeIDAttrOrderInvariance — Lua 表遍历顺序与定义顺序无关；
// 同 attrs 集合不同源序应得同 ID（由 Go-side 字典序排序保证）。
func TestForgeIDAttrOrderInvariance(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	specA := `{
		item_id = 100000001, count = 1, race = 0, season_seed = 0, stones = {},
		attrs = {
			{attr_id="phyAttack",         value=10},
			{attr_id="critical",          value=5},
			{attr_id="magicalSkillBoost", value=20},
		}
	}`
	specB := `{
		item_id = 100000001, count = 1, race = 0, season_seed = 0, stones = {},
		attrs = {
			{attr_id="magicalSkillBoost", value=20},
			{attr_id="phyAttack",         value=10},
			{attr_id="critical",          value=5},
		}
	}`
	a, b := callForgeID(t, L, specA), callForgeID(t, L, specB)
	if a != b {
		t.Errorf("ID 应不依赖 attrs 输入顺序: A=%s B=%s", a, b)
	}
}

// TestForgeIDStoneOrderMatters — stones 顺序是有意义的（槽位绑定属性差），
// 故顺序不同的 stones 必须给出不同 ID。
func TestForgeIDStoneOrderMatters(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	a := callForgeID(t, L, `{
		item_id=1, count=1, race=0, season_seed=0,
		stones={1001, 1002, 0, 0, 0, 0}, attrs={},
	}`)
	b := callForgeID(t, L, `{
		item_id=1, count=1, race=0, season_seed=0,
		stones={1002, 1001, 0, 0, 0, 0}, attrs={},
	}`)
	if a == b {
		t.Errorf("stones 顺序应当影响 ID，但得到相同 ID: %s", a)
	}
}

// TestForgeIDIntegrationWithRandomAttr — 集成: random_attr 流程末尾
// log forge ID，且 SP 调用次数与 v1 一致（forge_id 不引入额外副作用）。
func TestForgeIDIntegrationWithRandomAttr(t *testing.T) {
	world := ecs.NewWorld()
	const gwSeqID = uint64(7777)
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gwSeqID})
	world.SetStat(eid, "char_id", 424242)

	db := &recordingDB{}
	bridge := &Bridge{ECS: world, DB: db, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	callLua(t, L, `
		entropy.add_item_with_random_attr(
		    7777, 100000001, 1,
		    "Gladiator", "rare", 2, 0xC0FFEE)
	`)
	if got := db.calls.Load(); got != 1 {
		t.Fatalf("forge_id 集成不应改变 SP 调用次数: 期望 1, 得 %d", got)
	}
}

// itoaForLua — 把 int64 嵌入 Lua 源码的小帮手（避免 fmt 在测试里依赖）。
func itoaForLua(n int64) string {
	if n == 0 {
		return "0"
	}
	neg := false
	if n < 0 {
		neg = true
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
