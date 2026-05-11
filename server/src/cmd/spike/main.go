// Package main implements the AionCore Round 12 P1 client-capability SPIKE
// harness — the "real" version of the Sprint 0 客户端能力 spike that was
// flagged F3-Critical by Round 10 deep audit (whitepaper-20260425 was paper
// only, never injected anything).
//
// 本 binary 不连接真 5.8 客户端 (dev 环境无客户端二进制)，而是用三种角度
// 实测 4 边界假设：
//
//  1. **PG 直注** — 用 pgxpool 直接 INSERT/UPDATE user_item / user_item_option
//     模拟"GM 工具或 SQL 直注后客户端登录"的场景，回读字段验证 SP/schema
//     不会拒绝 (字段类型/范围) — 真客户端 inventory packet 解码同样依赖这些
//     字段在 NCSoft schema 范围内。
//  2. **Lua 直驱** — 用 luahost.NewVMPool 加载完整 scripts/，调
//     entropy.roll_random_attrs / entropy.add_item_with_stones / season_pool
//     在边界输入下跑，断言"无 panic + 字段格式合规 + 决定性"。这等价于
//     "真客户端拿到 SM_LOOT_ITEMLIST 时 server 端是否会先于发包就崩"。
//  3. **协议规格反推** — 把 Lua 输出按 SM_LOOT_ITEMLIST wire format 序列化
//     (opcodes.go §SM_LOOT_ITEMLIST 注释)，用 tinyclient.parseLootItemlist
//     等价的逻辑 round-trip 一次，断言"如果真客户端按 wire 格式解析此包，
//     不会越界 / type mismatch / utf16 截断"。
//
// 设计原则：
//   - **不写 SQL 业务逻辑**：仅做 "把 entropy 写进 user_item_option / 立即 SELECT
//     回来 / 校验" 这种证据收集。仍 100% 走 PG schema 但绕过 SP（仅本工具，
//     不允许复制到 server 运行时）。
//   - **不动 R11 文件**：scripts/lib/ scripts/data/ cmd/tinyclient/ 全部只读。
//   - **report dir 集中**：每次 run 写 spike/reports/<edge>-<ts>.log，
//     whitepaper v2 直接 cite。
//
// CLI:
//
//	spike --edge stones        # 6 槽全填
//	spike --edge extreme_attr  # ×1.20 极值
//	spike --edge unknown_attr  # 不在 23 已知 attr_id 池
//	spike --edge season_swap   # 在线切池
//	spike --edge all           # 4 个全跑
//	spike --edge all --dsn "postgres://..." --char-id 424242
//
// 退出码:
//
//	0 = 全 PASS / WARN (绿黄)
//	1 = 至少一项 FAIL (红)
//	2 = UNKNOWN — 缺前置条件 (灰，e.g. PG 不可达)
package main

import (
	"context"
	"encoding/binary"
	"flag"
	"fmt"
	"log/slog"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/jackc/pgx/v5/pgxpool"
	lua "github.com/yuin/gopher-lua"

	"aion58/internal/luahost"
)

// ---------------------------------------------------------------------------
// 评级 — Round 12 P1 任务规格 (4 级)
// ---------------------------------------------------------------------------

// Verdict 是单个 spike step 的评级。
type Verdict int

const (
	VerdictPass    Verdict = iota // 🟢 server 响应正常，字段合法
	VerdictWarn                   // 🟡 server 响应但字段可疑
	VerdictFail                   // 🔴 panic / drop / 越界
	VerdictUnknown                // ⚪ 测不了，缺前置
)

// String 返回带 emoji 的中文评级。whitepaper / log 都吃这个。
func (v Verdict) String() string {
	switch v {
	case VerdictPass:
		return "🟢 PASS"
	case VerdictWarn:
		return "🟡 WARN"
	case VerdictFail:
		return "🔴 FAIL"
	case VerdictUnknown:
		return "⚪ UNKNOWN"
	}
	return "?"
}

// StepResult 是单个 step 的执行结果。汇总到 EdgeReport。
type StepResult struct {
	Name    string
	Verdict Verdict
	Detail  string // 多行细节，写进 log + whitepaper 表格
}

// EdgeReport 汇总单个 edge 的所有 step。
type EdgeReport struct {
	Edge      string
	Started   time.Time
	Steps     []StepResult
	Inference string // "若真客户端在此会怎样" 推论段
}

// Worst 返回所有 step 中最坏的评级 (用于 edge-level / suite-level rollup)。
func (r *EdgeReport) Worst() Verdict {
	worst := VerdictPass
	for _, s := range r.Steps {
		if s.Verdict > worst {
			worst = s.Verdict
		}
	}
	return worst
}

// ---------------------------------------------------------------------------
// main + flag 处理
// ---------------------------------------------------------------------------

func main() {
	var (
		edge      = flag.String("edge", "all", "edge to spike: stones|extreme_attr|unknown_attr|season_swap|all")
		dsn       = flag.String("dsn", defaultDSN(), "PostgreSQL DSN; defaults to 127.0.0.1:5432/aion_world_live")
		scripts   = flag.String("scripts", defaultScriptsDir(), "path to Lua scripts/")
		charID    = flag.Int("char-id", 9001, "char_id used for PG fixture rows")
		reportDir = flag.String("report-dir", filepath.Join("spike", "reports"), "directory to write per-edge logs")
		skipDB    = flag.Bool("skip-db", false, "run only Lua-driven spikes (PG offline)")
	)
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	if err := os.MkdirAll(*reportDir, 0o755); err != nil {
		logger.Error("spike: mkdir report-dir failed", "err", err)
		os.Exit(2)
	}

	logger.Info("spike: start",
		"edge", *edge, "dsn", maskDSN(*dsn), "scripts", *scripts,
		"char_id", *charID, "report_dir", *reportDir, "skip_db", *skipDB)

	// === 准备 PG (可选) ===
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	var pool *pgxpool.Pool
	if !*skipDB {
		var err error
		pool, err = pgxpool.New(ctx, *dsn)
		if err != nil {
			logger.Warn("spike: PG unreachable, falling back to Lua-only spike", "err", err)
		} else {
			defer pool.Close()
			if pErr := pool.Ping(ctx); pErr != nil {
				logger.Warn("spike: PG ping failed, falling back to Lua-only", "err", pErr)
				pool.Close()
				pool = nil
			} else {
				logger.Info("spike: PG connected")
			}
		}
	}

	// === 准备 Lua VM ===
	bridge := &luahost.Bridge{
		DB:     &noopDB{},
		Sender: &noopSender{},
	}
	pool2, err := luahost.NewVMPool(1, *scripts, bridge)
	if err != nil {
		logger.Error("spike: Lua VM init failed — entropy helpers unavailable", "err", err)
		os.Exit(2)
	}
	defer pool2.Close()
	L := pool2.Acquire()
	defer pool2.Release(L)
	logger.Info("spike: Lua VM ready", "scripts", *scripts)

	// === 调度 edges ===
	var reports []*EdgeReport
	switch strings.ToLower(*edge) {
	case "stones":
		reports = []*EdgeReport{spikeStones(ctx, pool, L, *charID)}
	case "extreme_attr":
		reports = []*EdgeReport{spikeExtremeAttr(ctx, pool, L, *charID)}
	case "unknown_attr":
		reports = []*EdgeReport{spikeUnknownAttr(ctx, pool, L, *charID)}
	case "season_swap":
		reports = []*EdgeReport{spikeSeasonSwap(ctx, L)}
	case "all":
		reports = []*EdgeReport{
			spikeStones(ctx, pool, L, *charID),
			spikeExtremeAttr(ctx, pool, L, *charID),
			spikeUnknownAttr(ctx, pool, L, *charID),
			spikeSeasonSwap(ctx, L),
		}
	default:
		logger.Error("spike: unknown --edge", "value", *edge,
			"allowed", "stones|extreme_attr|unknown_attr|season_swap|all")
		os.Exit(2)
	}

	// === 写报告 + 汇总评级 ===
	worstAll := VerdictPass
	for _, r := range reports {
		writeReport(*reportDir, r, logger)
		if w := r.Worst(); w > worstAll {
			worstAll = w
		}
	}

	logger.Info("spike: done", "worst_verdict", worstAll.String(), "edge_count", len(reports))
	switch worstAll {
	case VerdictFail:
		os.Exit(1)
	case VerdictUnknown:
		os.Exit(2)
	default:
		os.Exit(0)
	}
}

// ---------------------------------------------------------------------------
// Edge 1 — stones 6 槽全填
// ---------------------------------------------------------------------------

// spikeStones 验证 user_item_option 6 manastone 槽位全填的边界:
//
//   - PG 写得进去吗 (schema 6 列均存在 + INTEGER 范围接受)
//   - Lua entropy.roll_manastones 在 epic tier 下能否产 6 非零
//   - SM_LOOT_ITEMLIST wire layout 把 6 stones 编码后能否被 tinyclient.parseLootItemlist
//     等价逻辑还原
//
// 47 server 历史观察: stones 0 使用 5 个月 (whitepaper §1.1); schema 暴露 6 列。
// 假设: 客户端读取并显示 6 槽。本 spike 无法直接验证客户端 tooltip 渲染，
// 但可证明 server 端不会在生成阶段崩。
func spikeStones(ctx context.Context, pool *pgxpool.Pool, L *lua.LState, charID int) *EdgeReport {
	r := &EdgeReport{Edge: "stones-6-slot-full", Started: time.Now()}

	// --- step A: Lua 直驱: roll_manastones 在 epic tier 至少滚出 6 非零槽 ---
	{
		stones := callRollManastones(L, 999001, "weapon", "epic", 0xC0FFEE)
		nonZero := 0
		for _, s := range stones {
			if s != 0 {
				nonZero++
			}
		}
		var v Verdict
		var d string
		switch {
		case len(stones) != 6:
			v = VerdictFail
			d = fmt.Sprintf("roll_manastones 返回 len=%d, 期望 6", len(stones))
		case nonZero < 6:
			v = VerdictWarn
			d = fmt.Sprintf("epic tier 滚出 %d/6 非零槽 (whitepaper 假设客户端可承载 6); stones=%v", nonZero, stones)
		default:
			v = VerdictPass
			d = fmt.Sprintf("epic tier 6/6 非零槽，stones=%v", stones)
		}
		r.Steps = append(r.Steps, StepResult{Name: "lua.roll_manastones(epic)", Verdict: v, Detail: d})
	}

	// --- step B: PG 直注 6 stones + 回读，验证 schema/column 接受 ---
	if pool == nil {
		r.Steps = append(r.Steps, StepResult{
			Name: "pg.user_item_option.stones_full", Verdict: VerdictUnknown,
			Detail: "PG 不可达 — skip",
		})
	} else {
		r.Steps = append(r.Steps, pgInjectStones(ctx, pool, charID, []int64{167000487, 167000488, 167000489, 167000490, 167000491, 167000492}))
	}

	// --- step C: SM_LOOT_ITEMLIST wire round-trip with 6 stones ---
	{
		var sentinelEID uint32 = 0xDEADBEEF // wire-format sentinel; reinterpret to int32 at runtime
		body := encodeLootItemlist(int32(sentinelEID), 100000001, 1, 0xCAFE,
			"AB12CD34",
			[]int32{167000487, 167000488, 167000489, 167000490, 167000491, 167000492},
			nil)
		ok, parsedStones, _, err := parseLootItemlist(body)
		var v Verdict
		var d string
		if err != nil {
			v = VerdictFail
			d = "wire 解码失败: " + err.Error()
		} else if !ok || len(parsedStones) != 6 {
			v = VerdictFail
			d = fmt.Sprintf("解码 stone_count=%d, 期望 6", len(parsedStones))
		} else {
			v = VerdictPass
			d = fmt.Sprintf("wire round-trip OK; bytes=%d; stones=%v", len(body), parsedStones)
		}
		r.Steps = append(r.Steps, StepResult{Name: "wire.SM_LOOT_ITEMLIST(6 stones)", Verdict: v, Detail: d})
	}

	r.Inference = inferStonesEdge(r)
	return r
}

func inferStonesEdge(r *EdgeReport) string {
	worst := r.Worst()
	switch worst {
	case VerdictPass:
		return "Server 端可生成 + 持久化 + wire 编码 6 stones; 真客户端理论上读 stat_enchant_name0..5 全 6 列。" +
			" 残余风险: 客户端 5.8 tooltip 渲染上限可能仅 4 (NCSoft 历史 GM 没填), 须 alpha 阶段 IIS GM Tool wishid 测一次。"
	case VerdictWarn:
		return "Server 链路通但 Lua entropy 可能未稳定填满 6 槽; 高熵命题需要确认 epic tier 一直 6/6, 否则 lucky_seven +1 池在 5/6 → 6/6 是 noop。"
	case VerdictFail:
		return "Server 端就无法生成或编码 6 stones — 真客户端必收异常包; 高熵 v0 命题在此分支下崩。" +
			" 优先修 Lua roll_manastones / wire encoder, 然后再谈客户端实测。"
	}
	return "测不全"
}

// ---------------------------------------------------------------------------
// Edge 2 — random_attr ×1.20 极值
// ---------------------------------------------------------------------------

// spikeExtremeAttr 测 v3 season_pool crit_storm 池 (×1.20) 把 v1 random_attr
// value 推到 attr.max 的边界:
//
//   - magicalSkillBoost min=-55 max=65; ×1.20 应 clamp 到 65 (random_attr_helper.lua §5)
//   - critical max=30; crit_storm ×1.20 在 25→30 → clamp 到 30
//   - PG randomValue1..10 是 INTEGER, 接受任意 INT32 范围, 不会触发 server 拒绝
//
// 关键风险: 若 clamp 失效 → server 写 66 / 36 进 PG → 真客户端 tooltip 数值
// 可能落在 NCSoft item_random_option.xml 校验外 (max 是 NCSoft 实证)。
func spikeExtremeAttr(ctx context.Context, pool *pgxpool.Pool, L *lua.LState, charID int) *EdgeReport {
	r := &EdgeReport{Edge: "random_attr-extreme-x1.20", Started: time.Now()}

	// --- step A: Lua: 把 season_seed 调到 crit_storm 池, 跑 1000 次抽样 ---
	{
		seed := findSeasonSeedForPool(L, "crit_storm")
		var maxVal, minVal int64 = math.MinInt64, math.MaxInt64
		var maxAttr string
		var sampleCount, overMax int
		var rangeMap = map[string][2]int64{} // attr_id -> [observed_min, observed_max]
		for i := 0; i < 1000; i++ {
			attrs := callRollRandomAttrs(L, int64(i)+1, 1, "Sorcerer", "rare", 1, seed)
			for _, a := range attrs {
				sampleCount++
				rng := rangeMap[a.AttrID]
				if rng == ([2]int64{}) {
					rng = [2]int64{math.MaxInt64, math.MinInt64}
				}
				if a.Value < rng[0] {
					rng[0] = a.Value
				}
				if a.Value > rng[1] {
					rng[1] = a.Value
				}
				rangeMap[a.AttrID] = rng

				if a.Value > maxVal {
					maxVal = a.Value
					maxAttr = a.AttrID
				}
				if a.Value < minVal {
					minVal = a.Value
				}
				// 23 attr 池 (random_attr_helper.lua §1) 极值表:
				if mx, ok := pool_attr_max[a.AttrID]; ok && a.Value > int64(mx) {
					overMax++
				}
			}
		}

		var v Verdict
		var d string
		summary := summarizeAttrRanges(rangeMap)
		switch {
		case sampleCount == 0:
			v = VerdictFail
			d = "1000 抽样产 0 attr — Lua 路径崩或 cfg 问题"
		case overMax > 0:
			v = VerdictWarn
			d = fmt.Sprintf("1000 抽样: %d 个 attr value 超过 NCSoft 实证 max (clamp 失效); 最大=%d (%s); min=%d; 全 attr 范围=%s",
				overMax, maxVal, maxAttr, minVal, summary)
		default:
			v = VerdictPass
			d = fmt.Sprintf("1000 抽样: 0 越界; 最大=%d (%s); min=%d; 全 attr 范围=%s",
				maxVal, maxAttr, minVal, summary)
		}
		r.Steps = append(r.Steps, StepResult{Name: "lua.crit_storm.x1.20-clamp", Verdict: v, Detail: d})
	}

	// --- step B: PG 直注 randomValue=65 (max) 然后 randomValue=120 (越界) ---
	if pool == nil {
		r.Steps = append(r.Steps, StepResult{
			Name: "pg.user_item_option.randomValue_extremes", Verdict: VerdictUnknown,
			Detail: "PG 不可达 — skip",
		})
	} else {
		r.Steps = append(r.Steps, pgInjectExtremeAttr(ctx, pool, charID))
	}

	// --- step C: wire encode + parse 极值 attr (utf16 attr_id + int32 value) ---
	{
		attrs := []wireAttr{
			{AttrID: "magicalSkillBoost", Value: 65},
			{AttrID: "critical", Value: 30},
			{AttrID: "phyAttack", Value: 20},
			{AttrID: "magicalSkillBoost", Value: -2147483647}, // INT32 边界
			{AttrID: "critical", Value: 2147483647},
		}
		body := encodeLootItemlist(1, 100000001, 1, 1, "FFFFFFFF", []int32{0, 0, 0, 0, 0, 0}, attrs)
		ok, _, parsed, err := parseLootItemlist(body)
		var v Verdict
		var d string
		if err != nil || !ok {
			v = VerdictFail
			d = fmt.Sprintf("wire 解码失败: %v", err)
		} else if len(parsed) != len(attrs) {
			v = VerdictFail
			d = fmt.Sprintf("wire round-trip 丢失 attr: 编码 %d, 解码 %d", len(attrs), len(parsed))
		} else {
			matchOK := true
			for i := range attrs {
				if parsed[i].AttrID != attrs[i].AttrID || parsed[i].Value != attrs[i].Value {
					matchOK = false
					break
				}
			}
			if !matchOK {
				v = VerdictFail
				d = fmt.Sprintf("wire round-trip 字段不一致: 编码=%v 解码=%v", attrs, parsed)
			} else {
				v = VerdictPass
				d = fmt.Sprintf("wire 5 attr (含 INT32 边界) round-trip OK; bytes=%d", len(body))
			}
		}
		r.Steps = append(r.Steps, StepResult{Name: "wire.SM_LOOT_ITEMLIST(extreme attrs)", Verdict: v, Detail: d})
	}

	r.Inference = inferExtremeAttrEdge(r)
	return r
}

func inferExtremeAttrEdge(r *EdgeReport) string {
	worst := r.Worst()
	switch worst {
	case VerdictPass:
		return "season_pool ×1.20 池在 v1 helper 内全程 clamp 到 [min, max], 不会推 attr value 越过 NCSoft 实证范围。" +
			" 真客户端读 randomValueN 应在熟悉数值域内 — 无 tooltip 越位。" +
			" 残余风险: NCSoft 校验是否严格按 item_random_option.xml min/max 表 (whitepaper §3.4 已暗示),仍需 alpha tooltip 截图核对。"
	case VerdictWarn:
		return "Lua clamp 路径有少量越界, 真客户端可能在 tooltip 显示数字时舍位或显示乱字符。" +
			" 立即修 random_attr_helper.lua §5 clamp 顺序: pool 乘子后必须再 clamp 一次 (当前代码已有, 检查执行路径)。"
	case VerdictFail:
		return "极值 attr 进入 SP/wire 链路就崩, 高熵 v3 池 ×1.20 设计在此分支不可上线。" +
			" 必须先把 wire encoder 的 utf16/int32 边界 fix 完, 再谈 alpha 客户端测试。"
	}
	return "测不全"
}

// ---------------------------------------------------------------------------
// Edge 3 — unknown attr_id (不在 23 已知池)
// ---------------------------------------------------------------------------

// spikeUnknownAttr 验证 server 注入"客户端未声明" attr_id (例如 99 = 不在 23
// 实证池) 时的反应:
//
//   - Lua 端 entropy.roll_random_attrs 不会抽到 unknown (它只从 23 attr 池)
//     => 必须从外部强制注入。
//   - 通过 wire 直接编码 attr_id="unknown_attr_99" 看 parseLootItemlist 是否
//     能 round-trip (utf16 字符串 server 端不校验 = 透传, 客户端不识别就忽略)
//   - PG randomAttr1..10 是 INTEGER (NCSoft 是 attr_index, 不是 string), 注入
//     一个超大 int (e.g. 9999) 验证 PG 不拒绝。
//
// 真客户端假设: attr_id 在 client item_random_option.xml 声明, 否则 tooltip
// 行被吃 (whitepaper §3.4) 或 crash。本 spike 只能证明 server 不崩。
func spikeUnknownAttr(ctx context.Context, pool *pgxpool.Pool, L *lua.LState, charID int) *EdgeReport {
	r := &EdgeReport{Edge: "unknown-attr_id", Started: time.Now()}

	// --- step A: 验证 Lua entropy 是闭集合 — 100 抽样不出 23 池外 ---
	{
		var allAttrs = map[string]bool{}
		for i := 0; i < 100; i++ {
			attrs := callRollRandomAttrs(L, int64(i)+1, 1, "Gladiator", "epic", 2, int64(i))
			for _, a := range attrs {
				allAttrs[a.AttrID] = true
			}
		}
		// 列出 23 池
		known := knownAttrPool()
		var unknown []string
		for id := range allAttrs {
			if !known[id] {
				unknown = append(unknown, id)
			}
		}
		var v Verdict
		var d string
		if len(unknown) > 0 {
			v = VerdictWarn
			sort.Strings(unknown)
			d = fmt.Sprintf("Lua 抽样产生 %d 个池外 attr_id: %v — random_attr_pool 与 known 实证表脱节",
				len(unknown), unknown)
		} else {
			v = VerdictPass
			d = fmt.Sprintf("100 抽样 %d unique attr 全部在 23 实证池内", len(allAttrs))
		}
		r.Steps = append(r.Steps, StepResult{Name: "lua.attr_pool-closed-set", Verdict: v, Detail: d})
	}

	// --- step B: wire 强制注入 unknown attr_id 并 round-trip ---
	{
		attrs := []wireAttr{
			{AttrID: "magicalSkillBoost", Value: 30}, // 已知
			{AttrID: "ZZ_unknown_attr_99", Value: 7}, // 未知 (string)
			{AttrID: "phyAttack", Value: 12},         // 已知
		}
		body := encodeLootItemlist(2, 100000002, 1, 2, "00000000",
			[]int32{0, 0, 0, 0, 0, 0}, attrs)
		ok, _, parsed, err := parseLootItemlist(body)
		var v Verdict
		var d string
		switch {
		case err != nil || !ok:
			v = VerdictFail
			d = fmt.Sprintf("wire 解析失败: %v", err)
		case len(parsed) != 3:
			v = VerdictFail
			d = fmt.Sprintf("attr 数错位: enc=3, dec=%d", len(parsed))
		case parsed[1].AttrID != "ZZ_unknown_attr_99":
			v = VerdictFail
			d = fmt.Sprintf("unknown attr_id 字段被 mangle: %q", parsed[1].AttrID)
		default:
			v = VerdictPass
			d = "server wire 透传 unknown attr_id 字符串, 不做白名单校验 (符合 whitepaper §2.5)"
		}
		r.Steps = append(r.Steps, StepResult{Name: "wire.unknown-attr_id-roundtrip", Verdict: v, Detail: d})
	}

	// --- step C: PG randomAttr 列允许越界 INT32 (e.g. 9999) ---
	if pool == nil {
		r.Steps = append(r.Steps, StepResult{
			Name: "pg.randomAttr_unknown_id", Verdict: VerdictUnknown,
			Detail: "PG 不可达 — skip",
		})
	} else {
		r.Steps = append(r.Steps, pgInjectUnknownAttr(ctx, pool, charID))
	}

	r.Inference = inferUnknownAttrEdge(r)
	return r
}

func inferUnknownAttrEdge(r *EdgeReport) string {
	worst := r.Worst()
	switch worst {
	case VerdictPass:
		return "Server 不做 attr_id 白名单 — wire 包透传, PG 接受任意 INT32。" +
			" 真客户端拿到未声明 attr_id 大概率: (a) tooltip 行渲染空白, (b) 不 crash (NCSoft 5.8 已观察 30001/40009 等 high-id skill 同款行为)。" +
			" 高熵 v4+ 设计可放心扩展 attr 池到 28 (whitepaper 提到的 5 outlier 可逐个白盒解锁), 服务端零成本。"
	case VerdictWarn:
		return "Lua entropy 路径已经在污染白名单 (random_attr_pool 含外部 attr) — 高熵 ID 域定义不一致, 玩家会看到 forge_id 一致但 tooltip 不同的 ghost 物品。" +
			" 修法: 对齐 random_attr_pool §1 与 known_attr_pool() (本 spike 第三 step) 的同源数据。"
	case VerdictFail:
		return "Server wire 路径不能透传未知 attr — 高熵 v4 扩展 attr 池前必须修 wire encoder。"
	}
	return "测不全"
}

// ---------------------------------------------------------------------------
// Edge 4 — season_pool 在线切换 (不重启)
// ---------------------------------------------------------------------------

// spikeSeasonSwap 模拟"周一 00:00 自动切池"场景. v3 设计要求每周轮换 5 池
// (entropy-mechanisms.md v3 §):
//
//   - 同 seed 必同 pool (决定性, season_pool.lua §2)
//   - 不同 seed → 5 池 round-robin 至少出现 2 unique (5 个相邻 seed 即可)
//   - 切池前后 attr_bias / stone_delta 必须立即生效 (Lua hot-reload 已上,
//     运行时 active_pool(seed) 是纯函数, 无须重启)
//   - 切池前后玩家在线 ≠ 切池中途崩 (Lua state 共享 _G.entropy.season_pool,
//     无 mutable 状态)
//
// PG 本边界**无关** — season_pool 仅修饰 in-memory roll, 不写 DB schema。
// 本 spike 因此 100% Lua 驱动。
func spikeSeasonSwap(_ context.Context, L *lua.LState) *EdgeReport {
	r := &EdgeReport{Edge: "season_pool-online-swap", Started: time.Now()}

	// --- step A: 决定性 — 同 seed 同池 ---
	{
		const seed = int64(0xDEADBEEF)
		p1 := callActivePoolName(L, seed)
		p2 := callActivePoolName(L, seed)
		var v Verdict
		var d string
		if p1 != p2 {
			v = VerdictFail
			d = fmt.Sprintf("决定性破坏: same seed 两次返回 %s vs %s", p1, p2)
		} else {
			v = VerdictPass
			d = fmt.Sprintf("seed=%#x → pool=%s (确定性 OK)", seed, p1)
		}
		r.Steps = append(r.Steps, StepResult{Name: "lua.season_pool.deterministic", Verdict: v, Detail: d})
	}

	// --- step B: 5 池 round-robin — 5 相邻 seed 至少出现 ≥2 unique ---
	{
		var names []string
		uniq := map[string]bool{}
		for s := int64(0); s < 10; s++ {
			n := callActivePoolName(L, s)
			names = append(names, n)
			uniq[n] = true
		}
		var v Verdict
		var d string
		switch {
		case len(uniq) < 2:
			v = VerdictFail
			d = fmt.Sprintf("10 seed 只产 %d unique pool — round-robin 失败; samples=%v", len(uniq), names)
		case len(uniq) < 5:
			v = VerdictWarn
			d = fmt.Sprintf("10 seed 产 %d/5 unique (设计目标 5); samples=%v", len(uniq), names)
		default:
			v = VerdictPass
			d = fmt.Sprintf("10 seed 产 5 unique pool, samples=%v", names)
		}
		r.Steps = append(r.Steps, StepResult{Name: "lua.season_pool.round-robin", Verdict: v, Detail: d})
	}

	// --- step C: 切池前后 roll 一次 random_attr, 验证 attr_bias 立即生效 ---
	{
		// 找两个产不同池的 seed
		seedTide, ok1 := findSeasonSeedForPoolWithFallback(L, "tide_chaos")
		seedIron, ok2 := findSeasonSeedForPoolWithFallback(L, "iron_dawn")
		if !ok1 || !ok2 {
			r.Steps = append(r.Steps, StepResult{
				Name: "lua.season_pool.swap-while-online", Verdict: VerdictWarn,
				Detail: "未能定位 tide_chaos 或 iron_dawn seed; pools.lua 可能改了名",
			})
		} else {
			// 在 seedTide 下 1000 抽样, 算 magicalSkillBoost 平均值
			avgTide := avgAttrValue(L, "Sorcerer", "rare", 1, seedTide, "magicalSkillBoost")
			// 立刻切到 seedIron, 同条件 1000 抽样
			avgIron := avgAttrValue(L, "Sorcerer", "rare", 1, seedIron, "magicalSkillBoost")

			// tide_chaos: magicalSkillBoost ×1.15;  iron_dawn: 该 attr 不在 attr_bias → ×1.0
			diff := avgTide - avgIron
			var v Verdict
			var d string
			switch {
			case math.IsNaN(avgTide) || math.IsNaN(avgIron):
				v = VerdictFail
				d = "1000 抽样未抽到 magicalSkillBoost — Sorcerer rare bias 失效"
			case math.Abs(diff) < 0.5:
				v = VerdictWarn
				d = fmt.Sprintf("切池后 magicalSkillBoost 平均无变化: tide=%.2f iron=%.2f; v3 attr_bias 可能未生效",
					avgTide, avgIron)
			case diff < 0:
				v = VerdictWarn
				d = fmt.Sprintf("切池方向反: tide_chaos 应 ×1.15 拉高, 实测 tide=%.2f < iron=%.2f",
					avgTide, avgIron)
			default:
				v = VerdictPass
				d = fmt.Sprintf("切池立即生效: tide_chaos avg=%.2f vs iron_dawn avg=%.2f (diff=%.2f); 同进程内无须重启",
					avgTide, avgIron, diff)
			}
			r.Steps = append(r.Steps, StepResult{Name: "lua.season_pool.swap-while-online", Verdict: v, Detail: d})
		}
	}

	r.Inference = inferSeasonSwapEdge(r)
	return r
}

func inferSeasonSwapEdge(r *EdgeReport) string {
	worst := r.Worst()
	switch worst {
	case VerdictPass:
		return "season_pool.active_pool(seed) 是纯函数 + Lua hot-reload 1s 生效 → 周一 00:00 自动切池**不需要重启 server**, 也不会让在线玩家崩。" +
			" 高熵 v3 周轮换设计可直接上线; QQ 群机器人 (entropy.season_pool.active_name) 提前 24h 公告即可。" +
			" 残余风险: 切池瞬间已经握在手的物品 forge_id 是上周生成的 (那时的 attr_bias), 玩家可能感觉物品比预期弱 — 文案上须解释 'forge_id 锁定生成日'。"
	case VerdictWarn:
		return "Round-robin 或 attr_bias 偏弱; 切池玩家可能感觉不到差异, 高熵命题被稀释。" +
			" 检查: (a) season_pool.pools 是否仍 5 个, (b) tide_chaos.attr_bias.magicalSkillBoost 是否仍 1.15。"
	case VerdictFail:
		return "决定性破坏 / round-robin 失败 — 周轮换公告与现实不一致, 玩家信任崩塌。" +
			" 优先回滚 v3, 修 season_pool.lua §2 active_pool 函数。"
	}
	return "测不全"
}

// ---------------------------------------------------------------------------
// Lua 调用辅助
// ---------------------------------------------------------------------------

// luaAttr 是 Lua 抽到的一个 random_attr。
type luaAttr struct {
	AttrID string
	Value  int64
}

// callRollRandomAttrs 调 entropy.roll_random_attrs(item_id, count, class, tier, race, seed)
// 返回 [{attr_id, value}, ...]。
func callRollRandomAttrs(L *lua.LState, itemID, count int64, class, tier string, race, seed int64) []luaAttr {
	entropyTbl, ok := L.GetGlobal("entropy").(*lua.LTable)
	if !ok {
		return nil
	}
	fn := L.GetField(entropyTbl, "roll_random_attrs")
	if fn == lua.LNil {
		return nil
	}
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 1, Protect: true},
		lua.LNumber(float64(itemID)), lua.LNumber(float64(count)),
		lua.LString(class), lua.LString(tier),
		lua.LNumber(float64(race)), lua.LNumber(float64(seed)),
	); err != nil {
		return nil
	}
	ret := L.Get(-1)
	L.Pop(1)
	tbl, ok := ret.(*lua.LTable)
	if !ok {
		return nil
	}
	var out []luaAttr
	tbl.ForEach(func(_, v lua.LValue) {
		sub, ok := v.(*lua.LTable)
		if !ok {
			return
		}
		var a luaAttr
		if id, ok := L.GetField(sub, "attr_id").(lua.LString); ok {
			a.AttrID = string(id)
		}
		if val, ok := L.GetField(sub, "value").(lua.LNumber); ok {
			a.Value = int64(val)
		}
		out = append(out, a)
	})
	return out
}

// callRollManastones 调 entropy.roll_manastones(uid, class, tier, seed) -> [6]int64。
func callRollManastones(L *lua.LState, uid int64, class, tier string, seed int64) []int64 {
	entropyTbl, ok := L.GetGlobal("entropy").(*lua.LTable)
	if !ok {
		return nil
	}
	fn := L.GetField(entropyTbl, "roll_manastones")
	if fn == lua.LNil {
		return nil
	}
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 1, Protect: true},
		lua.LNumber(float64(uid)), lua.LString(class), lua.LString(tier),
		lua.LNumber(float64(seed)),
	); err != nil {
		return nil
	}
	ret := L.Get(-1)
	L.Pop(1)
	tbl, ok := ret.(*lua.LTable)
	if !ok {
		return nil
	}
	out := make([]int64, 0, 6)
	for i := 1; i <= 6; i++ {
		if num, ok := tbl.RawGetInt(i).(lua.LNumber); ok {
			out = append(out, int64(num))
		} else {
			out = append(out, 0)
		}
	}
	return out
}

// callActivePoolName 调 entropy.season_pool.active_name(seed) -> string。
func callActivePoolName(L *lua.LState, seed int64) string {
	entropyTbl, ok := L.GetGlobal("entropy").(*lua.LTable)
	if !ok {
		return "(no entropy table)"
	}
	sp, ok := L.GetField(entropyTbl, "season_pool").(*lua.LTable)
	if !ok {
		return "(no season_pool)"
	}
	fn := L.GetField(sp, "active_name")
	if fn == lua.LNil {
		return "(no active_name)"
	}
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 1, Protect: true},
		lua.LNumber(float64(seed))); err != nil {
		return "(call err: " + err.Error() + ")"
	}
	ret := L.Get(-1)
	L.Pop(1)
	if s, ok := ret.(lua.LString); ok {
		return string(s)
	}
	return "(non-string)"
}

// callActivePool 调 entropy.season_pool.active_pool(seed) -> table，取 .name 字段。
func callActivePoolInternalName(L *lua.LState, seed int64) string {
	entropyTbl, ok := L.GetGlobal("entropy").(*lua.LTable)
	if !ok {
		return ""
	}
	sp, ok := L.GetField(entropyTbl, "season_pool").(*lua.LTable)
	if !ok {
		return ""
	}
	fn := L.GetField(sp, "active_pool")
	if fn == lua.LNil {
		return ""
	}
	if err := L.CallByParam(lua.P{Fn: fn, NRet: 1, Protect: true},
		lua.LNumber(float64(seed))); err != nil {
		return ""
	}
	ret := L.Get(-1)
	L.Pop(1)
	tbl, ok := ret.(*lua.LTable)
	if !ok {
		return ""
	}
	if s, ok := L.GetField(tbl, "name").(lua.LString); ok {
		return string(s)
	}
	return ""
}

// findSeasonSeedForPool 找一个产指定池 (internal name) 的 seed; 0..9 轮询。
func findSeasonSeedForPool(L *lua.LState, internalName string) int64 {
	for s := int64(0); s < 10; s++ {
		if callActivePoolInternalName(L, s) == internalName {
			return s
		}
	}
	return 0 // fallback — 上层会基于实测结果给 WARN
}

// findSeasonSeedForPoolWithFallback 同 findSeasonSeedForPool 但返回 (seed, found)。
func findSeasonSeedForPoolWithFallback(L *lua.LState, internalName string) (int64, bool) {
	for s := int64(0); s < 10; s++ {
		if callActivePoolInternalName(L, s) == internalName {
			return s, true
		}
	}
	return 0, false
}

// avgAttrValue 1000 抽样, 返回指定 attr_id 的平均 value (无样本返回 NaN)。
func avgAttrValue(L *lua.LState, class, tier string, race, seed int64, attrID string) float64 {
	var sum int64
	var n int
	for i := 0; i < 1000; i++ {
		attrs := callRollRandomAttrs(L, int64(i)+1, 1, class, tier, race, seed)
		for _, a := range attrs {
			if a.AttrID == attrID {
				sum += a.Value
				n++
			}
		}
	}
	if n == 0 {
		return math.NaN()
	}
	return float64(sum) / float64(n)
}

// ---------------------------------------------------------------------------
// 已知 attr 池 / max 表 — 来自 random_attr_helper.lua §1
// ---------------------------------------------------------------------------

// knownAttrPool 返回 23 实证 attr_id 的 set。
func knownAttrPool() map[string]bool {
	return map[string]bool{
		"phyAttack": true, "magicalAttack": true, "magicalSkillBoost": true,
		"healSkillBoost": true, "critical": true, "magicalCritical": true,
		"hitAccuracy": true, "magicalHitAccuracy": true,
		"attackDelay": true, "boostCastingTime": true,
		"paralyze_arp": true, "silence_arp": true,
		"physicalDefend": true, "magicalResist": true, "magicalSkillBoostResist": true,
		"block": true, "parry": true, "dodge": true,
		"maxHp": true, "maxMp": true,
		"arParalyze": true, "arSilence": true, "speed": true,
	}
}

// pool_attr_max — 实证 max 上限, 用于"是否越界"快速判定。
var pool_attr_max = map[string]int{
	"phyAttack": 20, "magicalAttack": 21, "magicalSkillBoost": 65,
	"healSkillBoost": 35, "critical": 30, "magicalCritical": 10,
	"hitAccuracy": 40, "magicalHitAccuracy": 20,
	"attackDelay": 19, "boostCastingTime": 3,
	"paralyze_arp": 19, "silence_arp": 12,
	"physicalDefend": 50, "magicalResist": 15, "magicalSkillBoostResist": 20,
	"block": 119, "parry": 107, "dodge": 10,
	"maxHp": 109, "maxMp": 245,
	"arParalyze": 3, "arSilence": 9, "speed": 2,
}

// summarizeAttrRanges 把 rangeMap 按 attr_id 字典序串成短串, 用于 log。
func summarizeAttrRanges(rangeMap map[string][2]int64) string {
	keys := make([]string, 0, len(rangeMap))
	for k := range rangeMap {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var sb strings.Builder
	for i, k := range keys {
		if i > 0 {
			sb.WriteByte(',')
		}
		fmt.Fprintf(&sb, "%s=[%d,%d]", k, rangeMap[k][0], rangeMap[k][1])
	}
	return sb.String()
}

// ---------------------------------------------------------------------------
// PG 直注 helpers (绕过 SP — 仅 spike 工具)
// ---------------------------------------------------------------------------

// pgInjectStones 注入 6 stones 到 user_item_option 然后 SELECT 回比对。
func pgInjectStones(ctx context.Context, pool *pgxpool.Pool, charID int, stones []int64) StepResult {
	step := StepResult{Name: "pg.user_item_option.stones_full"}

	// 1. INSERT 一个孤立 user_item (绑定 char_id)
	var itemID int64
	err := pool.QueryRow(ctx, `
		INSERT INTO user_item (char_id, name_id, slot_id, amount)
		VALUES ($1, $2, $3, $4)
		RETURNING id
	`, charID, 100000001, 0, 1).Scan(&itemID)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "INSERT user_item 失败: " + err.Error()
		return step
	}

	// 确保结束时清理 — 即使 step 结果异常也不污染 DB
	defer func() {
		_, _ = pool.Exec(ctx, `DELETE FROM user_item WHERE id = $1`, itemID)
	}()

	// 2. UPSERT user_item_option 6 stones
	_, err = pool.Exec(ctx, `
		INSERT INTO user_item_option (id, char_id,
		    stat_enchant_name0, stat_enchant_name1, stat_enchant_name2,
		    stat_enchant_name3, stat_enchant_name4, stat_enchant_name5,
		    option_count)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, itemID, charID,
		stones[0], stones[1], stones[2], stones[3], stones[4], stones[5], 6)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "INSERT user_item_option 失败: " + err.Error()
		return step
	}

	// 3. SELECT 回来比对
	var got [6]int64
	err = pool.QueryRow(ctx, `
		SELECT stat_enchant_name0, stat_enchant_name1, stat_enchant_name2,
		       stat_enchant_name3, stat_enchant_name4, stat_enchant_name5
		FROM user_item_option WHERE id = $1
	`, itemID).Scan(&got[0], &got[1], &got[2], &got[3], &got[4], &got[5])
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "SELECT user_item_option 失败: " + err.Error()
		return step
	}

	// 4. 比对
	for i := range stones {
		if got[i] != stones[i] {
			step.Verdict = VerdictFail
			step.Detail = fmt.Sprintf("slot %d round-trip 不一致: 写 %d 读 %d", i, stones[i], got[i])
			return step
		}
	}
	step.Verdict = VerdictPass
	step.Detail = fmt.Sprintf("INSERT+SELECT round-trip OK: 6 stones 全部回读一致 (item_id=%d)", itemID)
	return step
}

// pgInjectExtremeAttr 验证 PG schema 防御层 (CHECK constraint [-345, 245])：
//
//	Part 1: 合法值 (max-1=64, max=65) 应被接受
//	Part 2: 越界值 (120, INT_MAX) 应被 CHECK 约束拒绝
//
// STORY-1 (2026-05-06) 加 schema 防御层后，"越界被拒"是 PASS 而不是 FAIL。
// 单层 Lua clamp 可被 GM 工具直注 / 第三方运营脚本绕过；schema 是最后栅栏。
func pgInjectExtremeAttr(ctx context.Context, pool *pgxpool.Pool, charID int) StepResult {
	step := StepResult{Name: "pg.user_item_option.randomValue_extremes"}

	// --- Part 1: 合法值应被接受 ---
	var legalItemID int64
	err := pool.QueryRow(ctx, `
		INSERT INTO user_item (char_id, name_id, slot_id, amount)
		VALUES ($1, $2, $3, $4) RETURNING id
	`, charID, 160000001, 0, 1).Scan(&legalItemID)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "Part1 INSERT user_item failed: " + err.Error()
		return step
	}
	defer pool.Exec(ctx, `DELETE FROM user_item WHERE id = $1`, legalItemID)

	_, err = pool.Exec(ctx, `
		INSERT INTO user_item_option (id, char_id,
		    randomAttr1, randomValue1, randomAttr2, randomValue2)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, legalItemID, charID,
		3, 64, // magicalSkillBoost = 64 (max-1, legal)
		3, 65, // = 65 (max, legal)
	)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "Part1 合法值被错误拒绝 (schema 过严): " + err.Error()
		return step
	}

	var v1, v2 int32
	err = pool.QueryRow(ctx, `
		SELECT randomValue1, randomValue2 FROM user_item_option WHERE id = $1
	`, legalItemID).Scan(&v1, &v2)
	if err != nil || v1 != 64 || v2 != 65 {
		step.Verdict = VerdictFail
		step.Detail = fmt.Sprintf("Part1 回读异常: 期望 64/65, 得 %d/%d, err=%v", v1, v2, err)
		return step
	}

	// --- Part 2: 越界值应被 CHECK 约束拒绝 (STORY-1 防御层) ---
	var extremeItemID int64
	err = pool.QueryRow(ctx, `
		INSERT INTO user_item (char_id, name_id, slot_id, amount)
		VALUES ($1, $2, $3, $4) RETURNING id
	`, charID, 160000003, 0, 1).Scan(&extremeItemID)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "Part2 INSERT user_item failed: " + err.Error()
		return step
	}
	defer pool.Exec(ctx, `DELETE FROM user_item WHERE id = $1`, extremeItemID)

	_, err = pool.Exec(ctx, `
		INSERT INTO user_item_option (id, char_id,
		    randomAttr1, randomValue1, randomAttr2, randomValue2)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, extremeItemID, charID,
		3, 120, // 越界 (实证 magicalSkillBoost max=65)
		3, 2147483647, // INT32 上限
	)
	if err == nil {
		step.Verdict = VerdictFail
		step.Detail = "Part2 越界 randomValue (120, INT_MAX) 未被 schema 拒绝 — STORY-1 防御层失效"
		return step
	}
	if !strings.Contains(err.Error(), "randomvalue") && !strings.Contains(err.Error(), "check") {
		step.Verdict = VerdictFail
		step.Detail = "Part2 越界 INSERT 失败但非 CHECK 约束错误: " + err.Error()
		return step
	}

	step.Verdict = VerdictPass
	step.Detail = "防御层验证 OK: 合法值 (64, 65) 被接受, 越界值 (120, INT_MAX) 被 schema CHECK 拒绝 (STORY-1)。" +
		" Lua clamp + PG schema 双层防御对齐, entropy v1 假设成立。"
	return step
}

// pgInjectUnknownAttr 注入 randomAttr=9999 (NCSoft 未声明) 验证 PG 不拒绝。
func pgInjectUnknownAttr(ctx context.Context, pool *pgxpool.Pool, charID int) StepResult {
	step := StepResult{Name: "pg.randomAttr_unknown_id"}

	var itemID int64
	err := pool.QueryRow(ctx, `
		INSERT INTO user_item (char_id, name_id, slot_id, amount)
		VALUES ($1, $2, $3, $4) RETURNING id
	`, charID, 160000002, 0, 1).Scan(&itemID)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "INSERT user_item failed: " + err.Error()
		return step
	}
	defer pool.Exec(ctx, `DELETE FROM user_item WHERE id = $1`, itemID)

	_, err = pool.Exec(ctx, `
		INSERT INTO user_item_option (id, char_id, randomAttr1, randomValue1)
		VALUES ($1, $2, $3, $4)
	`, itemID, charID, 9999, 7) // attr_id 9999 无 NCSoft 客户端声明
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "INSERT 9999 attr_id failed: " + err.Error()
		return step
	}

	var got int32
	err = pool.QueryRow(ctx, `SELECT randomAttr1 FROM user_item_option WHERE id = $1`, itemID).Scan(&got)
	if err != nil {
		step.Verdict = VerdictFail
		step.Detail = "SELECT failed: " + err.Error()
		return step
	}
	if got != 9999 {
		step.Verdict = VerdictFail
		step.Detail = fmt.Sprintf("PG 改写值: 9999 → %d", got)
		return step
	}
	step.Verdict = VerdictPass
	step.Detail = "PG 接受 attr_id=9999 (NCSoft 未声明), schema INTEGER 不做白名单 — server 无栅栏, 风险下放给客户端容错。"
	return step
}

// ---------------------------------------------------------------------------
// SM_LOOT_ITEMLIST wire encode/parse — 与 tinyclient.parseLootItemlist 镜像
// ---------------------------------------------------------------------------

type wireAttr struct {
	AttrID string
	Value  int32
}

// encodeLootItemlist 按 opcodes.go SM_LOOT_ITEMLIST 注释序列化 (LE)。
// header (opcode etc.) 不在内, 仅 payload。
func encodeLootItemlist(corpseEID, itemID, itemCount, itemUID int32,
	forgeID string, stones []int32, attrs []wireAttr) []byte {

	var buf []byte
	app := func(b []byte) { buf = append(buf, b...) }
	appI32 := func(v int32) {
		var t [4]byte
		binary.LittleEndian.PutUint32(t[:], uint32(v))
		app(t[:])
	}

	appI32(corpseEID)
	appI32(itemID)
	appI32(itemCount)
	appI32(itemUID)

	// forge_id: 8 字节 ASCII (null-pad / truncate)
	pad := []byte(forgeID)
	if len(pad) < 8 {
		pad = append(pad, make([]byte, 8-len(pad))...)
	} else if len(pad) > 8 {
		pad = pad[:8]
	}
	app(pad)

	appI32(int32(len(stones)))
	for _, s := range stones {
		appI32(s)
	}

	appI32(int32(len(attrs)))
	for _, a := range attrs {
		// utf16 LE + null term
		runes := utf16.Encode([]rune(a.AttrID))
		for _, r := range runes {
			var t [2]byte
			binary.LittleEndian.PutUint16(t[:], r)
			app(t[:])
		}
		app([]byte{0x00, 0x00})
		appI32(a.Value)
	}
	return buf
}

// parseLootItemlist — 与 tinyclient.parseLootItemlist 等价 (但本 spike 自有副本
// 以避免依赖 cmd/tinyclient 包；R11 所有权)。
func parseLootItemlist(body []byte) (ok bool, stones []int32, attrs []wireAttr, err error) {
	const minLen = 4 + 4 + 4 + 4 + 8 + 4
	if len(body) < minLen {
		return false, nil, nil, fmt.Errorf("body too short: %d < %d", len(body), minLen)
	}
	off := 0
	_ = int32(binary.LittleEndian.Uint32(body[off:])) // corpseEID
	off += 4
	_ = int32(binary.LittleEndian.Uint32(body[off:])) // itemID
	off += 4
	_ = int32(binary.LittleEndian.Uint32(body[off:])) // itemCount
	off += 4
	_ = int32(binary.LittleEndian.Uint32(body[off:])) // itemUID
	off += 4
	_ = string(body[off : off+8])                     // forgeID
	off += 8

	stoneCount := int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	if stoneCount < 0 || stoneCount > 32 {
		return false, nil, nil, fmt.Errorf("absurd stone_count=%d", stoneCount)
	}
	if off+int(stoneCount)*4 > len(body) {
		return false, nil, nil, fmt.Errorf("stones truncated")
	}
	stones = make([]int32, stoneCount)
	for i := int32(0); i < stoneCount; i++ {
		stones[i] = int32(binary.LittleEndian.Uint32(body[off:]))
		off += 4
	}

	if off+4 > len(body) {
		return true, stones, nil, nil // 没 attrs 段也合法
	}
	attrCount := int32(binary.LittleEndian.Uint32(body[off:]))
	off += 4
	if attrCount < 0 || attrCount > 64 {
		return false, stones, nil, fmt.Errorf("absurd attr_count=%d", attrCount)
	}
	for i := int32(0); i < attrCount; i++ {
		name, n := readUTF16NullAt(body, off)
		off += n
		if off+4 > len(body) {
			return false, stones, attrs, fmt.Errorf("attr value truncated at idx %d", i)
		}
		val := int32(binary.LittleEndian.Uint32(body[off:]))
		off += 4
		attrs = append(attrs, wireAttr{AttrID: name, Value: val})
	}
	return true, stones, attrs, nil
}

// readUTF16NullAt 读 utf16 LE null-terminated 字符串, 返回 (string, 已消费 bytes)。
// 与 cmd/tinyclient 不同的是: 本副本支持完整 UTF-16 → UTF-8 (含 supplementary plane),
// 非 ASCII 字符正确还原, 便于 unknown_attr_id 测试包含中文 / 高位 codepoint 时仍准确。
func readUTF16NullAt(body []byte, off int) (string, int) {
	var codes []uint16
	consumed := 0
	for off+consumed+1 < len(body) {
		c := binary.LittleEndian.Uint16(body[off+consumed:])
		consumed += 2
		if c == 0 {
			break
		}
		codes = append(codes, c)
	}
	return string(utf16.Decode(codes)), consumed
}

// ---------------------------------------------------------------------------
// 报告 / I/O helpers
// ---------------------------------------------------------------------------

// writeReport 写一个 edge 的 markdown log + 在 stdout 打印 summary。
func writeReport(dir string, r *EdgeReport, logger *slog.Logger) {
	fname := filepath.Join(dir, fmt.Sprintf("%s-%s.log",
		r.Edge, r.Started.Format("20060102-150405")))
	f, err := os.Create(fname)
	if err != nil {
		logger.Error("spike: create report failed", "edge", r.Edge, "err", err)
		return
	}
	defer f.Close()

	fmt.Fprintf(f, "# Spike Report — %s\n\n", r.Edge)
	fmt.Fprintf(f, "Started: %s\n\n", r.Started.Format(time.RFC3339))
	fmt.Fprintf(f, "Worst verdict: **%s**\n\n", r.Worst())
	fmt.Fprintln(f, "## Steps")
	fmt.Fprintln(f, "")
	fmt.Fprintln(f, "| # | Name | Verdict | Detail |")
	fmt.Fprintln(f, "|---|------|---------|--------|")
	for i, s := range r.Steps {
		// markdown safety: 转义 |
		detail := strings.ReplaceAll(s.Detail, "|", "\\|")
		fmt.Fprintf(f, "| %d | `%s` | %s | %s |\n", i+1, s.Name, s.Verdict, detail)
	}
	fmt.Fprintln(f, "")
	fmt.Fprintln(f, "## Inference (若真客户端在此会怎样)")
	fmt.Fprintln(f, "")
	fmt.Fprintln(f, r.Inference)

	logger.Info("spike: report written",
		"edge", r.Edge, "file", fname,
		"worst", r.Worst().String(), "steps", len(r.Steps))
	for _, s := range r.Steps {
		logger.Info("  step", "name", s.Name, "verdict", s.Verdict.String(), "detail", truncate(s.Detail, 200))
	}
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}

// defaultDSN 返回 dev 环境默认 DSN。生产环境必须显式 --dsn。
func defaultDSN() string {
	if v := os.Getenv("AIONCORE_SPIKE_DSN"); v != "" {
		return v
	}
	pw := os.Getenv("AIONCORE_DB_PASS")
	if pw == "" {
		pw = "postgres" // 与 dev/config/world.toml 默认一致
	}
	return fmt.Sprintf("postgres://postgres:%s@127.0.0.1:5432/aion_world_live?sslmode=disable", pw)
}

// defaultScriptsDir 解析当前可执行所在目录附近的 scripts/。
// 优先级: $AIONCORE_SCRIPTS > ../../server/scripts > ../scripts > scripts
func defaultScriptsDir() string {
	if v := os.Getenv("AIONCORE_SCRIPTS"); v != "" {
		return v
	}
	candidates := []string{
		filepath.Join("..", "..", "server", "scripts"),
		filepath.Join("..", "..", "..", "scripts"),
		filepath.Join("..", "scripts"),
		"scripts",
	}
	for _, p := range candidates {
		if st, err := os.Stat(p); err == nil && st.IsDir() {
			return p
		}
	}
	return "scripts"
}

// maskDSN 截掉密码段, 仅 log 安全部分。
func maskDSN(dsn string) string {
	at := strings.Index(dsn, "@")
	if at <= 0 {
		return dsn
	}
	col := strings.LastIndex(dsn[:at], ":")
	if col <= 0 {
		return dsn
	}
	return dsn[:col+1] + "***" + dsn[at:]
}

// ---------------------------------------------------------------------------
// 占位 Bridge 依赖 — Lua VM 只读 entropy.* 不需要 DB/网络
// ---------------------------------------------------------------------------

type noopDB struct{}

func (noopDB) CallSP(_ context.Context, _ string, _ []any) ([]map[string]any, error) {
	return nil, nil
}

type noopSender struct{}

func (noopSender) SendToPlayer(_ uint64, _ uint16, _ []byte) error { return nil }
