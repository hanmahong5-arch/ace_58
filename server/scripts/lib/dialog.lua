-- scripts/lib/dialog.lua
-- NPC dialog framework.
--
-- Each NPC template registers a handler via dialog.register(template_id, fn).
-- The handler signature is:
--     handler(ctx, npc_eid, option_id)
-- where option_id == 0 means "initial open" (client just interacted with NPC).
--
-- Handlers should call dialog.send_window(gw, title, text, options) to display
-- a window on the client. Options is an array of { id=N, text="Label" }.
--
-- SM_DIALOG_WINDOW (0x6F) payload (LE, unverified):
--   int32        npc_entity_id
--   utf16_null   title
--   utf16_null   body
--   int32        option_count
--   repeat option_count:
--     int32       option_id
--     utf16_null  option_label

dialog = {}

local _registry = {}  -- template_id -> handler_fn

-- --------------------------------------------------------
-- dialog.register(template_id, fn)
-- Registers a dialog handler for an NPC template. Re-registering overrides.
-- --------------------------------------------------------
dialog.register = function(template_id, fn)
    if type(template_id) ~= "number" or type(fn) ~= "function" then
        log.warn("dialog.register: bad arguments")
        return
    end
    _registry[template_id] = fn
end

-- --------------------------------------------------------
-- dialog.has(template_id) -> bool
-- --------------------------------------------------------
dialog.has = function(template_id)
    return _registry[template_id] ~= nil
end

-- --------------------------------------------------------
-- dialog.open(ctx, npc_eid) -> bool
-- Called by CM_DIALOG_REQUEST handler. Dispatches to the registered handler
-- with option_id = 0 (initial open). Returns true if a handler ran.
-- --------------------------------------------------------
dialog.open = function(ctx, npc_eid)
    local tmpl = entity.get_npc_template(npc_eid)
    local fn = _registry[tmpl]
    if not fn then
        log.info("dialog.open: no handler for template=" .. tostring(tmpl))
        return false
    end
    fn(ctx, npc_eid, 0)
    return true
end

-- --------------------------------------------------------
-- dialog.select(ctx, npc_eid, option_id) -> bool
-- Called by CM_DIALOG_SELECT handler. Dispatches to the same registered
-- handler with the chosen option_id.
-- --------------------------------------------------------
dialog.select = function(ctx, npc_eid, option_id)
    local tmpl = entity.get_npc_template(npc_eid)
    local fn = _registry[tmpl]
    if not fn then
        return false
    end
    fn(ctx, npc_eid, option_id)
    return true
end

-- --------------------------------------------------------
-- dialog.send_window(gw, npc_eid, title, body, options)
-- Builds and sends SM_DIALOG_WINDOW (0x6F) to a single player.
-- options: array of { id=N, text="Label" }. nil/empty → zero options.
-- --------------------------------------------------------
dialog.send_window = function(gw, npc_eid, title, body, options)
    local buf = bytes.new()
    buf:write_int32(npc_eid)
    buf:write_string_utf16(title or "")
    buf:write_string_utf16(body or "")

    local opts = options or {}
    buf:write_int32(#opts)
    for _, opt in ipairs(opts) do
        buf:write_int32(opt.id or 0)
        buf:write_string_utf16(opt.text or "")
    end

    player.send_packet(gw, 0x6F, buf:to_string())
end
