-- scripts/npcs/npc_798007.lua
-- Beshmundir Temple — entrance NPC (Phase S-19).
--
-- 6-man group dungeon. The entrance NPC enforces party-leader gating: only
-- the party leader can open the "Enter" path; non-leaders see an informative
-- "ask your leader" message. Reset is offered at a 200k kinah fee.

local TEMPLATE_ID = 300320000
local OPT_ENTER   = 1
local OPT_RESET   = 2
local OPT_EXIT    = 99

dialog.register(798007, function(ctx, npc_eid, option_id)
    local gw  = ctx.gateway_seq_id
    local eid = ctx.entity_id

    if option_id == 0 then
        dialog.send_window(gw, npc_eid,
            "Beshmundir Guardian",
            "The temple's gates shimmer. Do you and your allies seek entry?",
            {
                { id = OPT_ENTER, text = "Enter with party (leader only)" },
                { id = OPT_RESET, text = "Reset cooldown (200000 kinah)"  },
                { id = OPT_EXIT,  text = "Depart"                         },
            })
        return
    end

    if option_id == OPT_ENTER then
        -- Leader gating: must be in a group AND be the leader.
        local g = group and group.get and group.get(eid)
        if not g then
            chat.send_system(gw,
                "Beshmundir Temple requires a party of at least 2.")
            return
        end
        if g.leader ~= eid then
            chat.send_system(gw, "Only the party leader may enter.")
            return
        end

        local run_id, reason = instance.create(eid, TEMPLATE_ID)
        if run_id then
            log.info("npc_798007: entered Beshmundir run_id=" .. tostring(run_id)
                .. " leader_eid=" .. tostring(eid))
        else
            chat.send_system(gw, "Cannot enter Beshmundir: " .. tostring(reason))
        end
        return
    end

    if option_id == OPT_RESET then
        local ok, reason = instance.reset(eid, TEMPLATE_ID)
        if ok then
            chat.send_system(gw, "Beshmundir cooldown cleared.")
        else
            chat.send_system(gw, "Reset failed: " .. tostring(reason))
        end
        return
    end
end)
