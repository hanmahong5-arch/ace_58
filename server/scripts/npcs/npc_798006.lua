-- scripts/npcs/npc_798006.lua
-- Haramel Training Grounds — entrance NPC (Phase S-19).
--
-- Shows the player an "Enter Training Grounds" dialog. Selecting the Enter
-- option fabricates a CM_INSTANCE_ENTER equivalent by calling instance.create
-- directly; we skip the packet round-trip since the handler would do exactly
-- the same thing. Errors surface via a chat system message so the player
-- knows why they were rejected (cooldown, under-level, etc.).

local TEMPLATE_ID    = 300040000
local OPT_ENTER      = 1
local OPT_RESET      = 2
local OPT_EXIT       = 99

dialog.register(798006, function(ctx, npc_eid, option_id)
    local gw  = ctx.gateway_seq_id
    local eid = ctx.entity_id

    if option_id == 0 then
        dialog.send_window(gw, npc_eid,
            "Haramel Guide",
            "A solo training ground tuned for novices. Enter?",
            {
                { id = OPT_ENTER, text = "Enter Training Grounds" },
                { id = OPT_RESET, text = "Reset cooldown (1000 kinah)" },
                { id = OPT_EXIT,  text = "Leave"                      },
            })
        return
    end

    if option_id == OPT_ENTER then
        local run_id, reason = instance.create(eid, TEMPLATE_ID)
        if run_id then
            log.info("npc_798006: entered Haramel run_id=" .. tostring(run_id))
        else
            chat.send_system(gw, "Cannot enter Haramel: " .. tostring(reason))
        end
        return
    end

    if option_id == OPT_RESET then
        local ok, reason = instance.reset(eid, TEMPLATE_ID)
        if ok then
            chat.send_system(gw, "Haramel cooldown cleared.")
        else
            chat.send_system(gw, "Reset failed: " .. tostring(reason))
        end
        return
    end
    -- OPT_EXIT: client closes window; nothing more to do.
end)
