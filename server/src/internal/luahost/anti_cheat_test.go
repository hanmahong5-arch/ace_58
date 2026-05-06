// Package luahost — anti_cheat.lua unit tests (W4 standalone).
//
// 这一组测试故意避开 newS14Bridge 等大 harness：本库是无 handler 的纯 Lua
// 模块，吃 caller 注入的 (eid, x, y, z, tick) 数据，*不* 依赖完整 ECS。
// 因此用一个最小 VM + 直接 DoFile 加载 lib + Lua 侧 stub 出一个可控的
// entity.get_position 桩。
package luahost

import (
	"path/filepath"
	"testing"

	lua "github.com/yuin/gopher-lua"
)

// newAntiCheatVM spins up a clean Lua VM, loads anti_cheat.lua, and installs
// an _G.entity stub backed by a Lua table so check_attack can look up
// "authoritative" positions per attacker/target eid in tests.
//
// Tests configure positions by:
//
//	L.DoString(`_pos[<eid>] = { x=10, y=0, z=0 }`)
func newAntiCheatVM(t *testing.T) *lua.LState {
	t.Helper()
	L := lua.NewState(lua.Options{SkipOpenLibs: false})
	t.Cleanup(L.Close)

	// Pull anti_cheat.lua from the script tree relative to package CWD,
	// matching the s14ScriptsDir convention.
	libPath := filepath.Join("..", "..", "..", "scripts", "lib", "anti_cheat.lua")
	if err := L.DoFile(libPath); err != nil {
		t.Fatalf("load anti_cheat.lua: %v", err)
	}

	// Install a Lua-only entity.get_position stub. The lib only calls this
	// from check_attack; check_move feeds (x, y, z) directly so it does not
	// touch entity.*.
	if err := L.DoString(`
		_pos = {}
		entity = {
			get_position = function(eid)
				return _pos[eid] or { x=0, y=0, z=0 }
			end,
		}
	`); err != nil {
		t.Fatalf("install entity stub: %v", err)
	}
	return L
}

// runLua is a small helper that fails the test on Lua compile/run errors.
func runLua(t *testing.T, L *lua.LState, src string) {
	t.Helper()
	if err := L.DoString(src); err != nil {
		t.Fatalf("DoString:\n%s\nerr: %v", src, err)
	}
}

// ----------------------------------------------------------------------------
// check_move
// ----------------------------------------------------------------------------

// 首次 move 没有 baseline，必须直接通过（只刷 baseline）。
func TestAntiCheat_CheckMove_FirstCallPasses(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `_ok, _r = anti_cheat.check_move(1, 100, 0, 0, 100)`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("first move should pass, got ok=%v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
}

// 合法速度（< 1.5x base）必须通过。
// 11 m/s base * 1.5 = 16.5 m/s 上限。
// 1 秒 (20 ticks) 走 5m → 5 m/s ≪ 16.5，OK。
func TestAntiCheat_CheckMove_LegitSpeedPasses(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_move(1, 0, 0, 0, 100)         -- baseline
		_ok, _r = anti_cheat.check_move(1, 5, 0, 0, 120)
	`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("5 m/s should pass, got ok=%v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
}

// 距离 100m / 时间 1 秒 = 100 m/s ≫ 16.5，必须拒。
func TestAntiCheat_CheckMove_SpeedHackDenied(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_move(1, 0, 0, 0, 100)
		_ok, _r = anti_cheat.check_move(1, 100, 0, 0, 120)
	`)
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("100 m/s should be denied, got ok=%v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("speed_hack") {
		t.Errorf("want reason=speed_hack, got %v", L.GetGlobal("_r"))
	}
}

// reset 后再 move 等价于首次 — baseline 重新建立，第一次 OK。
func TestAntiCheat_CheckMove_ResetClearsBaseline(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_move(1, 0, 0, 0, 100)
		anti_cheat.reset(1)
		-- 没有 baseline：第一次必须 OK，无视巨距。
		_ok = anti_cheat.check_move(1, 9999, 0, 0, 200)
	`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("post-reset first move should pass, got %v", L.GetGlobal("_ok"))
	}
}

// 时钟回退（恶意 client 篡 ts，但本库吃 server tick — 这里相当于上层 caller
// 失误传入回退 tick），返回 tick_regression。
func TestAntiCheat_CheckMove_TickRegressionDenied(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_move(1, 0, 0, 0, 200)
		_ok, _r = anti_cheat.check_move(1, 1, 0, 0, 100)
	`)
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("tick regression must deny, got %v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("tick_regression") {
		t.Errorf("want reason=tick_regression, got %v", L.GetGlobal("_r"))
	}
}

// ----------------------------------------------------------------------------
// check_attack
// ----------------------------------------------------------------------------

// 距离 < max_range，OK。
func TestAntiCheat_CheckAttack_InRange(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		_pos[10] = { x=0, y=0, z=0 }
		_pos[20] = { x=3, y=0, z=0 }
		_ok, _r = anti_cheat.check_attack(10, 20, 5)
	`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("3m attack at 5m range should pass, got %v reason=%v",
			L.GetGlobal("_ok"), L.GetGlobal("_r"))
	}
}

// 距离正好等于 max_range + buffer 边界 (5 + 0.5)，OK。
func TestAntiCheat_CheckAttack_BoundaryWithBufferPasses(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		_pos[10] = { x=0, y=0, z=0 }
		_pos[20] = { x=5.5, y=0, z=0 }
		_ok = anti_cheat.check_attack(10, 20, 5)
	`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("attack at exactly max_range+buffer should pass, got %v",
			L.GetGlobal("_ok"))
	}
}

// 距离明显超过 max_range + buffer，拒绝。
func TestAntiCheat_CheckAttack_OutOfRangeDenied(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		_pos[10] = { x=0, y=0, z=0 }
		_pos[20] = { x=20, y=0, z=0 }
		_ok, _r = anti_cheat.check_attack(10, 20, 5)
	`)
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("20m attack at 5m range should be denied, got %v",
			L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("out_of_range") {
		t.Errorf("want reason=out_of_range, got %v", L.GetGlobal("_r"))
	}
}

// ----------------------------------------------------------------------------
// check_skill_cd
// ----------------------------------------------------------------------------

// 首次施放：OK，记录 tick。
func TestAntiCheat_CheckSkillCd_FirstCastPasses(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `_ok = anti_cheat.check_skill_cd(1, 1001, 100, 40)`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("first cast should pass, got %v", L.GetGlobal("_ok"))
	}
}

// cd 内重发：拒绝。cd=40 ticks，第二次在 100+39=139 早于 140 → cooldown。
func TestAntiCheat_CheckSkillCd_WithinCooldownDenied(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_skill_cd(1, 1001, 100, 40)
		_ok, _r = anti_cheat.check_skill_cd(1, 1001, 139, 40)
	`)
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("within cd should be denied, got %v", L.GetGlobal("_ok"))
	}
	if L.GetGlobal("_r") != lua.LString("cooldown") {
		t.Errorf("want reason=cooldown, got %v", L.GetGlobal("_r"))
	}
}

// cd 满后再发：OK。
func TestAntiCheat_CheckSkillCd_AfterCooldownPasses(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_skill_cd(1, 1001, 100, 40)
		_ok = anti_cheat.check_skill_cd(1, 1001, 141, 40)
	`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("after cd should pass, got %v", L.GetGlobal("_ok"))
	}
}

// ----------------------------------------------------------------------------
// APS sliding window
// ----------------------------------------------------------------------------

// max_aps=5：1 秒内 5 次 record，aps_within_limit 必须 true。
func TestAntiCheat_AttacksWithinLimit(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		for t = 100, 104 do anti_cheat.record_attack(1, t) end
		-- 检测时刻 = 104，窗口 = (104-20, 104] = (84, 104]，全部 5 次落入。
		_ok = anti_cheat.aps_within_limit(1, 104, 5)
	`)
	if L.GetGlobal("_ok") != lua.LTrue {
		t.Errorf("5 attacks in 1s should be within max_aps=5, got %v",
			L.GetGlobal("_ok"))
	}
}

// 1 秒内 6 次 record，max_aps=5 必须拒。
func TestAntiCheat_AttacksExceedingLimit(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		for t = 100, 105 do anti_cheat.record_attack(1, t) end
		_ok = anti_cheat.aps_within_limit(1, 105, 5)
	`)
	if L.GetGlobal("_ok") != lua.LFalse {
		t.Errorf("6 attacks in 1s with max_aps=5 should fail, got %v",
			L.GetGlobal("_ok"))
	}
}

// ----------------------------------------------------------------------------
// reset semantics
// ----------------------------------------------------------------------------

// reset 后所有内部状态归零：再调 skill_cd、aps、move 都等同首次。
func TestAntiCheat_ResetClearsAllState(t *testing.T) {
	L := newAntiCheatVM(t)
	runLua(t, L, `
		anti_cheat.check_move(1, 0, 0, 0, 100)
		anti_cheat.check_skill_cd(1, 1001, 100, 40)
		for t = 100, 105 do anti_cheat.record_attack(1, t) end
		anti_cheat.reset(1)
		-- 全部状态应当清零。
		_move_first = anti_cheat.check_move(1, 9999, 0, 0, 200)  -- 无 baseline → ok
		_cd_first   = anti_cheat.check_skill_cd(1, 1001, 200, 40) -- 无记录 → ok
		_aps_clean  = anti_cheat.aps_within_limit(1, 205, 5)      -- 窗口空 → ok
	`)
	if L.GetGlobal("_move_first") != lua.LTrue {
		t.Error("post-reset move should pass as first")
	}
	if L.GetGlobal("_cd_first") != lua.LTrue {
		t.Error("post-reset skill should pass as first")
	}
	if L.GetGlobal("_aps_clean") != lua.LTrue {
		t.Error("post-reset aps window should be clean")
	}
}
