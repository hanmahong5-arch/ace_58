-- scripts/lib/router.lua
-- Central CM_* packet dispatch table.  Loaded before handler scripts (lib/ loads first).
--
-- Usage in handler files:
--   register_handler(0x11, function(ctx, payload) ... end)
--
-- The Go Dispatcher calls dispatch_packet(opcode, ctx_table, payload_string) on every
-- CM_* packet received from a game-port client.

local _handlers = {}

-- register_handler(opcode, fn)
-- Registers a handler function for a CM_* opcode.
-- fn signature: function(ctx, payload_reader)
--   ctx.gateway_seq_id  uint64  Gateway session identifier (use for player.send_packet)
--   ctx.entity_id       uint64  ECS entity ID for this player
--   ctx.account_id      int64   Database account ID
--   ctx.account         string  Account name
--   payload_reader      reader  bytes.reader over the raw packet payload (bytes after opcode)
function register_handler(opcode, fn)
    _handlers[opcode] = fn
end

-- dispatch_packet(opcode, ctx, raw_payload)
-- Called by the Go Dispatcher for every CM_* packet.
-- Wraps raw_payload in a bytes.reader and calls the registered handler.
function dispatch_packet(opcode, ctx, raw_payload)
    local h = _handlers[opcode]
    if not h then
        log.warn("no handler for opcode " .. string.format("0x%04X", opcode))
        return
    end
    local r = bytes.reader(raw_payload)
    local ok, err = pcall(h, ctx, r)
    if not ok then
        log.error("handler error opcode=" .. string.format("0x%04X", opcode)
            .. " account=" .. tostring(ctx and ctx.account or "?")
            .. " err=" .. tostring(err))
    end
end
