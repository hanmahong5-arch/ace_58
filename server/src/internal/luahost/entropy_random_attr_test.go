// Round 6 C4 — Entropy v1 random_attr 原型测试。
//
// 4 个测试覆盖 v1-design.md §3 (确定性) + §1.4 (多样性/熵估算) + §2 (class/race 偏置生效)。
//
// 注意：v1 仍是原型 stub —— bridge 只 log 不写 user_item_attribute，
// 故所有测试都不验证 SP 端写入；只验证 Lua 侧 roll 函数 + bridge 调用次数。

package luahost

import (
	"testing"

	lua "github.com/yuin/gopher-lua"

	"aion58/internal/ecs"
)

// callRollRandomAttrs 调用 entropy.roll_random_attrs 并解码返回 LTable。
// 返回 [{attr_id, value}, ...] 列表（长度 0..10）。
func callRollRandomAttrs(t *testing.T, L *lua.LState,
	itemID, count int64, itemClass, tier string, race, seasonSeed int64) []map[string]any {
	t.Helper()

	entropyTbl, ok := L.GetGlobal("entropy").(*lua.LTable)
	if !ok {
		t.Fatal("global `entropy` is not a table — random_attr_helper.lua not loaded?")
	}
	rollFn := L.GetField(entropyTbl, "roll_random_attrs")
	if rollFn == lua.LNil {
		t.Fatal("entropy.roll_random_attrs is not defined")
	}

	if err := L.CallByParam(lua.P{Fn: rollFn, NRet: 1, Protect: true},
		lua.LNumber(float64(itemID)),
		lua.LNumber(float64(count)),
		lua.LString(itemClass),
		lua.LString(tier),
		lua.LNumber(float64(race)),
		lua.LNumber(float64(seasonSeed)),
	); err != nil {
		t.Fatalf("entropy.roll_random_attrs: %v", err)
	}
	ret := L.Get(-1)
	L.Pop(1)

	tbl, ok := ret.(*lua.LTable)
	if !ok {
		t.Fatalf("non-table return: %T", ret)
	}
	out := make([]map[string]any, 0, 10)
	tbl.ForEach(func(_, v lua.LValue) {
		sub, ok := v.(*lua.LTable)
		if !ok {
			return
		}
		entry := make(map[string]any, 2)
		if id, ok := L.GetField(sub, "attr_id").(lua.LString); ok {
			entry["attr_id"] = string(id)
		}
		if val, ok := L.GetField(sub, "value").(lua.LNumber); ok {
			entry["value"] = int64(val)
		}
		out = append(out, entry)
	})
	return out
}

// TestEntropyRandomAttrEndToEnd — bridge 路径完整 e2e:
// Lua helper → bridge stub → legacy SP 调用一次。
func TestEntropyRandomAttrEndToEnd(t *testing.T) {
	world := ecs.NewWorld()
	const (
		gwSeqID = uint64(7777)
		charID  = float64(424242)
	)
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gwSeqID})
	world.SetStat(eid, "char_id", charID)

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
		t.Fatalf("expected 1 SP call, got %d", got)
	}
	if db.last.proc != "aion_AddItemUser" {
		t.Errorf("expected pass-through to legacy SP, got %q", db.last.proc)
	}

	// 同种子 → 同结果（确定性合约）
	a := callRollRandomAttrs(t, L, 100000001, 1, "Gladiator", "rare", 2, 0xC0FFEE)
	b := callRollRandomAttrs(t, L, 100000001, 1, "Gladiator", "rare", 2, 0xC0FFEE)
	if len(a) != 7 || len(b) != 7 {
		t.Fatalf("rare tier 应该 7 槽, got %d / %d", len(a), len(b))
	}
	for i := range a {
		if a[i]["attr_id"] != b[i]["attr_id"] || a[i]["value"] != b[i]["value"] {
			t.Errorf("非确定性 slot=%d: %v vs %v", i, a[i], b[i])
		}
	}
}

// TestEntropyRandomAttrMissingArgs — 容错：缺末尾 4 参也能 grant。
func TestEntropyRandomAttrMissingArgs(t *testing.T) {
	world := ecs.NewWorld()
	const gwSeqID = uint64(8888)
	eid := world.NewEntity()
	world.SetPlayer(eid, &ecs.PlayerComp{GatewaySeqID: gwSeqID})
	world.SetStat(eid, "char_id", 999999)

	db := &recordingDB{}
	bridge := &Bridge{ECS: world, DB: db, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	callLua(t, L, `entropy.add_item_with_random_attr(8888, 100000001, 1)`)

	if got := db.calls.Load(); got != 1 {
		t.Fatalf("expected 1 SP call, got %d", got)
	}
}

// TestEntropyRandomAttrDiversity — 100 次不同 (item_id, count) 应该至少
// 80 个唯一组合。entropy 设计要求"玩家 1000 小时还有惊喜"——若 100 次
// 中重复率 > 20% 说明 PRNG 有严重 collision，原型设计已坏。
func TestEntropyRandomAttrDiversity(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const sampleSize = 100
	const minUnique = 80
	const seasonSeed = int64(0xC0FFEE)

	seen := make(map[string]bool, sampleSize)
	for i := int64(1); i <= sampleSize; i++ {
		// 改变 item_id 保证 derive_subseed 输出不同
		attrs := callRollRandomAttrs(t, L, 100000000+i, 1, "Gladiator", "rare", 2, seasonSeed)
		// 序列化为字符串作为唯一键
		key := ""
		for _, a := range attrs {
			key += a["attr_id"].(string) + ":"
			if v, ok := a["value"].(int64); ok {
				key += string(rune(v + 1000)) + ","  // 简单字符化，碰撞概率低
			}
		}
		seen[key] = true
	}

	if len(seen) < minUnique {
		t.Errorf("多样性不足: %d 次抽样仅 %d 个唯一组合 (期望 ≥ %d)",
			sampleSize, len(seen), minUnique)
	} else {
		t.Logf("多样性 OK: %d 次抽样产生 %d 个唯一组合 (%.1f%%)",
			sampleSize, len(seen), float64(len(seen))*100/sampleSize)
	}
}

// TestEntropyRandomAttrClassBias — Gladiator + rare 1000 次抽样,
// phyAttack 应高频出现 (offensive 权重 1.6 vs default 1.0)。
func TestEntropyRandomAttrClassBias(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const samples = 1000
	const seasonSeed = int64(0xC0FFEE)

	gladiatorPhyAttack := 0
	defaultPhyAttack := 0

	for i := int64(1); i <= samples; i++ {
		// Gladiator: offensive 权重 1.6
		ga := callRollRandomAttrs(t, L, 100000000+i, 1, "Gladiator", "rare", 0, seasonSeed)
		for _, a := range ga {
			if a["attr_id"] == "phyAttack" {
				gladiatorPhyAttack++
				break
			}
		}
		// default: 等权 1.0
		da := callRollRandomAttrs(t, L, 200000000+i, 1, "default", "rare", 0, seasonSeed)
		for _, a := range da {
			if a["attr_id"] == "phyAttack" {
				defaultPhyAttack++
				break
			}
		}
	}

	gladPct := float64(gladiatorPhyAttack) * 100 / samples
	defPct := float64(defaultPhyAttack) * 100 / samples
	t.Logf("phyAttack 出现率: Gladiator=%.1f%% default=%.1f%%", gladPct, defPct)

	// Gladiator offensive weight=1.6 vs default 1.0 → 期望 Gladiator 比例
	// 显著高于 default。容差 5pp 处理统计噪声 (sample size 1000)。
	if gladPct <= defPct+5 {
		t.Errorf("class 偏置未生效: Gladiator %.1f%% 应明显 > default %.1f%% + 5pp",
			gladPct, defPct)
	}
}

// TestEntropyRandomAttrRaceBias — Elyos vs Asmodian 同 (item_id, count) 1000 次,
// magicalSkillBoost 出现比例应有显著差异 (Elyos 1.10 倍 race_bias)。
func TestEntropyRandomAttrRaceBias(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const samples = 1000
	const seasonSeed = int64(0xC0FFEE)

	elyosMagicalBoost := 0
	asmodianMagicalBoost := 0
	elyosPhyAttack := 0
	asmodianPhyAttack := 0

	// Sorcerer 让 magicalSkillBoost 已经被 offensive bias 1.6 抬高，
	// race 偏置在它之上额外乘 1.10。同时跟踪 phyAttack 验证 Asmodian 偏置。
	for i := int64(1); i <= samples; i++ {
		ea := callRollRandomAttrs(t, L, 100000000+i, 1, "Sorcerer", "rare", 1, seasonSeed)
		aa := callRollRandomAttrs(t, L, 100000000+i, 1, "Sorcerer", "rare", 2, seasonSeed)
		for _, a := range ea {
			if a["attr_id"] == "magicalSkillBoost" {
				elyosMagicalBoost++
			}
			if a["attr_id"] == "phyAttack" {
				elyosPhyAttack++
			}
		}
		for _, a := range aa {
			if a["attr_id"] == "magicalSkillBoost" {
				asmodianMagicalBoost++
			}
			if a["attr_id"] == "phyAttack" {
				asmodianPhyAttack++
			}
		}
	}

	t.Logf("magicalSkillBoost: Elyos=%d Asmodian=%d (期望 Elyos > Asmodian)",
		elyosMagicalBoost, asmodianMagicalBoost)
	t.Logf("phyAttack:         Elyos=%d Asmodian=%d (期望 Asmodian > Elyos)",
		elyosPhyAttack, asmodianPhyAttack)

	if elyosMagicalBoost <= asmodianMagicalBoost {
		t.Errorf("race 偏置未生效: Elyos magicalSkillBoost (%d) 应 > Asmodian (%d)",
			elyosMagicalBoost, asmodianMagicalBoost)
	}
	if asmodianPhyAttack <= elyosPhyAttack {
		t.Errorf("race 偏置未生效: Asmodian phyAttack (%d) 应 > Elyos (%d)",
			asmodianPhyAttack, elyosPhyAttack)
	}
}
