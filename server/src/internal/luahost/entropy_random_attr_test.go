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

// ---------------------------------------------------------------
// Round 9 C7 — 12 职业偏置补全 + legendary tier + fallback 测试
// ---------------------------------------------------------------

// classBiasCase: 一个职业 + 期望主属性 + 期望偏置生效的 tier。
// 主属性出现率必须 > default 同 attr 出现率 + 5pp（卡方判定差异显著）。
type classBiasCase struct {
	class     string // bias_matrix key
	tier      string // common / rare / epic / legendary
	primary   string // 该 tier 的主属性 attr_id (权重最高)
	tagline   string // 一句话定位（出错信息可读化）
}

// TestEntropyRandomAttrAllClasses — 12 职业 × 1000 抽样:
// 1) 每职业的"主属性"出现率 > default 同 attr + 5pp（class bias 生效）
// 2) 多样性 ≥ 80 unique 组合（avoiding ceiling-only 设计）
//
// 这是 v4 候选 #1 "9 职业偏置补全" 的回归测试 — 一旦未来调权重把某职业
// 主属性 ceiling 抹平，此测试会立即失败。
func TestEntropyRandomAttrAllClasses(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const samples = 1000
	const seasonSeed = int64(0xC0FFEE)
	const minUnique = 80
	const biasGapPp = 5.0

	cases := []classBiasCase{
		// 战士系
		{"Gladiator", "rare", "phyAttack", "物理双手近战 + 防反"},
		{"Templar", "rare", "physicalDefend", "重盾坦克 + 嘲讽"},
		// 侦察系
		{"Assassin", "rare", "phyAttack", "物理 burst + 高命中"},
		{"Ranger", "rare", "phyAttack", "物理远程 + 风筝"},
		// 法师系
		{"Sorcerer", "rare", "magicalAttack", "魔攻爆发 + AoE"},
		{"Spiritmaster", "rare", "magicalSkillBoost", "宠物 + DoT"},
		// 治疗系
		{"Cleric", "rare", "healSkillBoost", "主奶 + 生存防御"},
		{"Chanter", "rare", "healSkillBoost", "辅助 buff + 物理混合"},
		// 5.x 工程系
		{"Aethertech", "rare", "phyAttack", "重型机甲 + 远程物理"},
		{"Gunslinger", "rare", "phyAttack", "双枪机动 + 多目标"},
		// 5.x 巫师系
		{"Songweaver", "rare", "magicalAttack", "远程魔法 + 控场 buff"},
		{"Bard", "rare", "magicalSkillBoost", "团 buff/debuff + 治疗副"},
	}

	// 先收集 default 在每个 attr 上的 baseline 出现率（共用一次, 12 职业平均节省 11000 次抽样）
	defaultHits := make(map[string]int, 23)
	defaultUnique := make(map[string]bool, samples)
	for i := int64(1); i <= samples; i++ {
		attrs := callRollRandomAttrs(t, L, 900000000+i, 1, "default", "rare", 0, seasonSeed)
		key := ""
		for _, a := range attrs {
			id, _ := a["attr_id"].(string)
			defaultHits[id]++
			key += id + ","
		}
		defaultUnique[key] = true
	}
	t.Logf("default baseline (rare, 1000 抽样) — phyAttack=%.1f%% magicalAttack=%.1f%% magicalSkillBoost=%.1f%% healSkillBoost=%.1f%% physicalDefend=%.1f%% (多样性=%d)",
		float64(defaultHits["phyAttack"])*100/samples,
		float64(defaultHits["magicalAttack"])*100/samples,
		float64(defaultHits["magicalSkillBoost"])*100/samples,
		float64(defaultHits["healSkillBoost"])*100/samples,
		float64(defaultHits["physicalDefend"])*100/samples,
		len(defaultUnique))

	if len(defaultUnique) < minUnique {
		t.Errorf("default 多样性不足: %d 抽样仅 %d unique (期望 ≥ %d) — 说明 PRNG 退化或槽抽样有 collision",
			samples, len(defaultUnique), minUnique)
	}

	// 12 职业循环
	pass := 0
	for _, c := range cases {
		primaryHits := 0
		uniqueSet := make(map[string]bool, samples)
		for i := int64(1); i <= samples; i++ {
			// 改 item_id 保证 derive_subseed 散列
			attrs := callRollRandomAttrs(t, L, 100000000+i, 1, c.class, c.tier, 0, seasonSeed)
			seenPrimary := false
			key := ""
			for _, a := range attrs {
				id, _ := a["attr_id"].(string)
				if id == c.primary {
					seenPrimary = true
				}
				key += id + ","
			}
			if seenPrimary {
				primaryHits++
			}
			uniqueSet[key] = true
		}
		classPct := float64(primaryHits) * 100 / samples
		defPct := float64(defaultHits[c.primary]) * 100 / samples

		ok := true
		if classPct < defPct+biasGapPp {
			t.Errorf("[%s/%s] %s 偏置未生效: %s 出现率 %.1f%% 应 > default %.1f%% + %.1fpp",
				c.class, c.tier, c.tagline, c.primary, classPct, defPct, biasGapPp)
			ok = false
		}
		if len(uniqueSet) < minUnique {
			t.Errorf("[%s/%s] 多样性不足: %d 抽样仅 %d unique (期望 ≥ %d)",
				c.class, c.tier, samples, len(uniqueSet), minUnique)
			ok = false
		}
		if ok {
			pass++
			t.Logf("[%s/%s] %s — %s=%.1f%% (vs default %.1f%%, 差 %+.1fpp), 多样性=%d ✓",
				c.class, c.tier, c.tagline, c.primary, classPct, defPct, classPct-defPct, len(uniqueSet))
		}
	}
	t.Logf("12 职业偏置生效汇总: %d / %d PASS", pass, len(cases))
}

// TestEntropyRandomAttrFallback — 未知职业必须 fallback 到 default,
// 与显式传 "default" 行为完全一致（同 item_id 同 seed 同 attrs 同 values）。
//
// 防御场景: 客户端传 "Inquisitor" 这种 4.x 职业名 / typo "Glad" / 空串。
func TestEntropyRandomAttrFallback(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const seasonSeed = int64(0xC0FFEE)

	unknowns := []string{"Inquisitor", "Glad", "", "FooBar", "DragonKnight"}
	for _, u := range unknowns {
		// Roll once with unknown, once with explicit "default"; same item_id/seed → same result.
		a := callRollRandomAttrs(t, L, 555000001, 1, u, "rare", 1, seasonSeed)
		b := callRollRandomAttrs(t, L, 555000001, 1, "default", "rare", 1, seasonSeed)
		if len(a) != len(b) {
			t.Errorf("unknown class %q: 槽数 %d != default 槽数 %d", u, len(a), len(b))
			continue
		}
		for i := range a {
			if a[i]["attr_id"] != b[i]["attr_id"] || a[i]["value"] != b[i]["value"] {
				t.Errorf("unknown class %q: slot %d 与 default 不一致 — %v vs %v", u, i, a[i], b[i])
			}
		}
		t.Logf("unknown class %q → fallback to default ✓ (%d slots match)", u, len(a))
	}
}

// TestEntropyRandomAttrLegendaryTier — Round 9 C7 新增 tier:
// 1) legendary 槽数 = 12（最大）
// 2) 与 epic 共享 categories（offensive/defensive/resist/utility）
// 3) 主属性偏置仍生效（不退化为 baseline）
func TestEntropyRandomAttrLegendaryTier(t *testing.T) {
	bridge := &Bridge{DB: &mockDB{}, Sender: &mockSender{}}
	L := newTestState(t, bridge)
	defer L.Close()

	const seasonSeed = int64(0xC0FFEE)
	const samples = 500

	// (a) 槽数 = 12（不放回上限被 23 attr × 4 cat = ~22 限制, 但 12 槽 ≤ 22 OK）
	attrs := callRollRandomAttrs(t, L, 100000001, 1, "Gladiator", "legendary", 2, seasonSeed)
	if len(attrs) != 12 {
		t.Fatalf("legendary 应有 12 槽, got %d", len(attrs))
	}

	// (b) 主属性偏置: Gladiator legendary phyAttack=22 vs default baseline=1
	gladHits := 0
	defHits := 0
	for i := int64(1); i <= samples; i++ {
		ga := callRollRandomAttrs(t, L, 100000000+i, 1, "Gladiator", "legendary", 0, seasonSeed)
		da := callRollRandomAttrs(t, L, 200000000+i, 1, "default", "legendary", 0, seasonSeed)
		for _, a := range ga {
			if a["attr_id"] == "phyAttack" {
				gladHits++
				break
			}
		}
		for _, a := range da {
			if a["attr_id"] == "phyAttack" {
				defHits++
				break
			}
		}
	}
	gladPct := float64(gladHits) * 100 / samples
	defPct := float64(defHits) * 100 / samples
	t.Logf("legendary phyAttack: Gladiator=%.1f%% default=%.1f%% (差 %+.1fpp)", gladPct, defPct, gladPct-defPct)
	if gladPct <= defPct+5 {
		t.Errorf("legendary 偏置未生效: Gladiator phyAttack %.1f%% 应 > default %.1f%% + 5pp", gladPct, defPct)
	}

	// (c) 同 seed 同 class 同 tier → 同结果（决定性）
	a := callRollRandomAttrs(t, L, 100000001, 1, "Gladiator", "legendary", 2, seasonSeed)
	b := callRollRandomAttrs(t, L, 100000001, 1, "Gladiator", "legendary", 2, seasonSeed)
	for i := range a {
		if a[i]["attr_id"] != b[i]["attr_id"] || a[i]["value"] != b[i]["value"] {
			t.Errorf("legendary 非确定性 slot=%d: %v vs %v", i, a[i], b[i])
		}
	}
}
