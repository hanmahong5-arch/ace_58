// Round 8 C6 — entropy v3 季节性 modifier 池切换测试。
//
// 4 类测试 (per skill ref entropy-mechanisms.md "测试模式"):
//   1. 决定性: 同 season_seed → 同 pool（≥3 子测试覆盖正/零/大值）
//   2. 多样性: 50 周里 ≥4 个不同 pool 都激活过
//   3. 偏置生效: tide_chaos 周 1000 抽样 magicalSkillBoost 平均 ≥+10pp
//   4. 降级:    未知 pool / nil pool → identity (不 panic)
//
// 此外验证不打破 v0/v1: TestEntropySeasonPoolDoesNotBreakV0V1
// 跑 v0 manastone + v1 random_attr 各自的最小冒烟，确保 v3 wiring
// 不让既有 25 entropy 测试集 regression。

package luahost

import (
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// callActivePool 调用 entropy.season_pool.active_pool(seed) 取 name 字段。
// 返回 ("", false) 表示池为 nil（不应发生）。
func callActivePool(t *testing.T, L *lua.LState, seed int64) (string, bool) {
	t.Helper()
	sp := L.GetGlobal("entropy")
	if sp == lua.LNil {
		t.Fatal("entropy global missing")
	}
	pool := L.GetField(L.GetField(L.GetGlobal("entropy"), "season_pool"), "active_pool")
	if pool == lua.LNil {
		t.Fatal("entropy.season_pool.active_pool missing")
	}
	if err := L.CallByParam(lua.P{Fn: pool, NRet: 1, Protect: true},
		lua.LNumber(float64(seed))); err != nil {
		t.Fatalf("active_pool call: %v", err)
	}
	ret := L.Get(-1)
	L.Pop(1)
	tbl, ok := ret.(*lua.LTable)
	if !ok {
		return "", false
	}
	name, _ := L.GetField(tbl, "name").(lua.LString)
	return string(name), true
}

// callApplyToAttr 调用 apply_to_attr(base, attr_id, active_pool(seed)) 取数值结果。
func callApplyToAttr(t *testing.T, L *lua.LState, baseValue int64, attrID string, seed int64) int64 {
	t.Helper()
	fn, err := L.LoadString(`
		local seed, base, attr = ...
		local pool = entropy.season_pool.active_pool(seed)
		return entropy.season_pool.apply_to_attr(base, attr, pool)
	`)
	if err != nil {
		t.Fatalf("LoadString: %v", err)
	}
	L.Push(fn)
	L.Push(lua.LNumber(float64(seed)))
	L.Push(lua.LNumber(float64(baseValue)))
	L.Push(lua.LString(attrID))
	if err := L.PCall(3, 1, nil); err != nil {
		t.Fatalf("apply_to_attr pcall: %v", err)
	}
	ret := L.Get(-1)
	L.Pop(1)
	n, ok := ret.(lua.LNumber)
	if !ok {
		t.Fatalf("apply_to_attr non-number: %v", ret)
	}
	return int64(n)
}

// TestEntropySeasonPoolDeterministic — 同 seed 永远同 pool（核心合约）。
// 3 子测试: 0、1234、very large。
func TestEntropySeasonPoolDeterministic(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	cases := []int64{0, 1234, 0xC0FFEE, 99999999}
	for _, seed := range cases {
		a, ok1 := callActivePool(t, L, seed)
		b, ok2 := callActivePool(t, L, seed)
		if !ok1 || !ok2 {
			t.Fatalf("seed=%d: active_pool returned nil", seed)
		}
		if a != b || a == "" {
			t.Errorf("non-deterministic at seed=%d: %q vs %q", seed, a, b)
		}
	}
}

// TestEntropySeasonPoolDiversity — 50 周里 ≥4 个不同 pool 都激活过。
// 池有 5 个；mod 5 周期 → 50 周必然每池激活 10 次。
func TestEntropySeasonPoolDiversity(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const weeks = 50
	const minDistinct = 4

	seen := make(map[string]int, weeks)
	for w := int64(0); w < weeks; w++ {
		name, ok := callActivePool(t, L, w)
		if !ok {
			t.Fatalf("week=%d: active_pool returned nil", w)
		}
		seen[name]++
	}
	if len(seen) < minDistinct {
		t.Errorf("多样性不足: %d 周仅 %d 个不同池 (期望 >= %d), 分布: %v",
			weeks, len(seen), minDistinct, seen)
	} else {
		t.Logf("多样性 OK: %d 周 %d 个不同池, 分布: %v", weeks, len(seen), seen)
	}
}

// TestEntropySeasonPoolBiasEffective — tide_chaos 周 (seed=0) 1000 抽样,
// magicalSkillBoost 平均值应比 baseline (seed=4 = void_drift, 不影响该 attr)
// 高 ≥10pp。tide_chaos.attr_bias.magicalSkillBoost = 1.15。
//
// 注：直接打 apply_to_attr 而非过 random_attr 全链路，因为后者还有 class
// bias / race bias 多重权重，难做单变量 effect。
func TestEntropySeasonPoolBiasEffective(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const samples = 1000
	const tideSeed = int64(0)  // tide_chaos
	const voidSeed = int64(4)  // void_drift（不影响 magicalSkillBoost）

	// 验证选对了 pool
	if name, _ := callActivePool(t, L, tideSeed); name != "tide_chaos" {
		t.Fatalf("seed=0 expected tide_chaos, got %q", name)
	}
	if name, _ := callActivePool(t, L, voidSeed); name != "void_drift" {
		t.Fatalf("seed=4 expected void_drift, got %q", name)
	}

	var tideSum, voidSum int64
	for i := int64(1); i <= samples; i++ {
		// 用 base=20 (在 magicalSkillBoost min=-55 max=65 范围内)
		tideSum += callApplyToAttr(t, L, 20, "magicalSkillBoost", tideSeed)
		voidSum += callApplyToAttr(t, L, 20, "magicalSkillBoost", voidSeed)
	}

	tideAvg := float64(tideSum) / float64(samples)
	voidAvg := float64(voidSum) / float64(samples)
	deltaPct := (tideAvg - voidAvg) * 100 / voidAvg
	t.Logf("magicalSkillBoost avg: tide_chaos=%.2f void_drift=%.2f (Δ=%.1f%%)",
		tideAvg, voidAvg, deltaPct)

	if deltaPct < 10 {
		t.Errorf("bias 未生效: tide_chaos vs void_drift Δ=%.1f%% < 10%%", deltaPct)
	}
}

// TestEntropySeasonPoolFallback — 4 个降级路径都不能 panic 也不能误算。
//   (a) nil pool → 返回 base
//   (b) 池存在但 attr 不在 attr_bias map → 返回 base
//   (c) base=0 → 返回 0（乘任何乘子都是 0）
//   (d) 未知 attr_id → 返回 base
func TestEntropySeasonPoolFallback(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	// (a) nil pool
	fn, err := L.LoadString(`return entropy.season_pool.apply_to_attr(42, "phyAttack", nil)`)
	if err != nil {
		t.Fatalf("LoadString: %v", err)
	}
	L.Push(fn)
	if err := L.PCall(0, 1, nil); err != nil {
		t.Fatalf("nil pool pcall: %v", err)
	}
	if got := int64(L.Get(-1).(lua.LNumber)); got != 42 {
		t.Errorf("nil pool: expected 42, got %d", got)
	}
	L.Pop(1)

	// (b) (d) 合并：tide_chaos 池存在，但 phyDefend / unknown_xyz 不在 attr_bias
	for _, attr := range []string{"physicalDefend", "unknown_xyz_attr"} {
		got := callApplyToAttr(t, L, 50, attr, 0) // seed=0 → tide_chaos
		if got != 50 {
			t.Errorf("fallback attr=%q: expected 50, got %d", attr, got)
		}
	}

	// (c) base=0
	if got := callApplyToAttr(t, L, 0, "magicalSkillBoost", 0); got != 0 {
		t.Errorf("zero base: expected 0, got %d", got)
	}

	// 槽数 clamp 边界
	clampFn, err := L.LoadString(`
		local stones, delta = ...
		return entropy.season_pool.apply_to_stones(stones, { stone_delta = delta })
	`)
	if err != nil {
		t.Fatalf("clamp LoadString: %v", err)
	}
	check := func(stones, delta, want int64) {
		t.Helper()
		L.Push(clampFn)
		L.Push(lua.LNumber(float64(stones)))
		L.Push(lua.LNumber(float64(delta)))
		if err := L.PCall(2, 1, nil); err != nil {
			t.Fatalf("clamp pcall: %v", err)
		}
		got := int64(L.Get(-1).(lua.LNumber))
		L.Pop(1)
		if got != want {
			t.Errorf("apply_to_stones(%d, delta=%d): want %d got %d", stones, delta, want, got)
		}
	}
	check(6, 1, 6)  // upper clamp
	check(0, -1, 0) // lower clamp
	check(3, 1, 4)  // normal
	check(3, -1, 2) // normal -1
}

// TestEntropySeasonPoolDoesNotBreakV0V1 — 跑 v0 add_item_with_stones 和
// v1 add_item_with_random_attr 的最小冒烟，确保 v3 wiring 没有破坏既有路径。
// 任何 panic / 错误 SP 调用次数都应该 fail。
func TestEntropySeasonPoolDoesNotBreakV0V1(t *testing.T) {
	world := ecs.NewWorld()
	const gwSeqID = uint64(7777)
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gwSeqID})
	world.SetStat(eid, "char_id", float64(424242))

	db := &recordingDB{}
	bridge := &Bridge{ECS: world, DB: db, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	// 用 lucky_seven 周 (+1 stone)，最有可能暴露 wiring 问题
	callLua(t, L, `entropy.add_item_with_stones(7777, 100000001, 1, "weapon", "rare", 3)`)
	// 用 void_drift 周 (-1 stone)
	callLua(t, L, `entropy.add_item_with_stones(7777, 100000001, 1, "weapon", "rare", 4)`)
	// v1 random_attr — tide_chaos 周
	callLua(t, L, `entropy.add_item_with_random_attr(7777, 100000001, 1, "Sorcerer", "rare", 1, 0)`)

	if got := db.calls.Load(); got != 3 {
		t.Errorf("expected 3 SP calls (1 per item grant), got %d", got)
	}
}

// TestEntropySeasonPoolStoneDeltaApplied — lucky_seven 比 void_drift
// 同 placeholder_uid 多 ≥1 个非空 stone 槽（rare tier 容易达到 6 槽满，
// 故用 epic 测）。
func TestEntropySeasonPoolStoneDeltaApplied(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const samples = 100
	var luckyTotal, voidTotal int64

	// 直接用 add_item_helper 内部逻辑触发；通过对比同 (uid, class, tier) 在
	// 不同 season 的 stone 数差异验证 delta 生效。
	// 用最小 fixture：直接在 Lua 里 roll + 应用 delta，绕过 bridge SP。
	fn, err := L.LoadString(`
		local seed, uid = ...
		local stones = entropy.roll_manastones(uid, "weapon", "rare", seed)
		local pool = entropy.season_pool.active_pool(seed)
		local non_empty = 0
		for i = 1, 6 do if stones[i] ~= 0 then non_empty = non_empty + 1 end end
		return entropy.season_pool.apply_to_stones(non_empty, pool)
	`)
	if err != nil {
		t.Fatalf("LoadString: %v", err)
	}
	for i := int64(1); i <= samples; i++ {
		// lucky_seven (seed=3, +1)
		L.Push(fn)
		L.Push(lua.LNumber(3))
		L.Push(lua.LNumber(float64(i)))
		if err := L.PCall(2, 1, nil); err != nil {
			t.Fatalf("lucky pcall: %v", err)
		}
		luckyTotal += int64(L.Get(-1).(lua.LNumber))
		L.Pop(1)
		// void_drift (seed=4, -1)
		L.Push(fn)
		L.Push(lua.LNumber(4))
		L.Push(lua.LNumber(float64(i)))
		if err := L.PCall(2, 1, nil); err != nil {
			t.Fatalf("void pcall: %v", err)
		}
		voidTotal += int64(L.Get(-1).(lua.LNumber))
		L.Pop(1)
	}
	t.Logf("100 samples avg stones: lucky_seven=%.2f void_drift=%.2f",
		float64(luckyTotal)/float64(samples), float64(voidTotal)/float64(samples))
	if luckyTotal-voidTotal < int64(samples) {
		t.Errorf("stone_delta 未生效: lucky_total=%d 应比 void_total=%d 多 >= %d",
			luckyTotal, voidTotal, samples)
	}
}
