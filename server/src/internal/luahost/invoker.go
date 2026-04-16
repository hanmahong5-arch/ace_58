package luahost

import (
	"errors"
	"fmt"

	lua "github.com/yuin/gopher-lua"
)

// ErrLuaGlobalMissing is returned by VMPool.CallGlobal when the requested
// function name is not a *lua.LFunction in the current VM globals. This
// typically means the event script has not been loaded or was renamed.
var ErrLuaGlobalMissing = errors.New("luahost: global function not found")

// CallGlobal borrows a VM from the pool, looks up a top-level function by
// name, converts each positional Go argument to a Lua value, invokes the
// function with protected mode, and releases the VM. It is the canonical
// Go→Lua entry point for background jobq workers that need to execute
// business logic written in Lua without going through the packet dispatcher.
//
// Rules:
//   - The global MUST be a function. Any other type returns ErrLuaGlobalMissing.
//   - Args support bool, int, int32, int64, float32, float64, string, nil.
//     Unsupported types are pushed as nil and logged by the caller via the
//     returned error when the callee uses a mismatched type.
//   - The call is made with Protect=true so a Lua error becomes a Go error
//     rather than crashing the process.
//   - Return values are discarded. Callers that need a return should extend
//     this helper or call lower-level pool primitives directly.
//
// Phase S-17 callers (in internal/jobq/workers.go):
//   on_auction_expire, on_legion_invite_expire, on_mail_deliver
func (p *VMPool) CallGlobal(fnName string, args ...any) error {
	if p == nil {
		return ErrLuaGlobalMissing
	}
	L := p.Acquire()
	defer p.Release(L)

	fn, ok := L.GetGlobal(fnName).(*lua.LFunction)
	if !ok {
		return fmt.Errorf("%w: %q", ErrLuaGlobalMissing, fnName)
	}

	base := L.GetTop()
	L.Push(fn)
	for _, a := range args {
		L.Push(goToLua(L, a))
	}
	if err := L.PCall(len(args), 0, nil); err != nil {
		L.SetTop(base)
		return fmt.Errorf("luahost: Lua call %q failed: %w", fnName, err)
	}
	L.SetTop(base)
	return nil
}
