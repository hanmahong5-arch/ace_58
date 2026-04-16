-- scripts/npcs/npc_798005.lua
-- Auction House Broker (Sanctum) — NPC template 798005.
--
-- Dialog flow is minimal: pointer to the four CM_AUCTION_* opcodes. The
-- actual Search/Register/Bid/Cancel UX is driven client-side by the
-- native Auction House window; the NPC just gates the opcode chain so
-- players cannot bypass the broker by sending CM_AUCTION_* from anywhere.
--
-- OPT_BROWSE and OPT_LIST serve as implicit "session open" markers that
-- auction.lua could later consult (not enforced in Phase S-16 MVP).

local OPT_EXIT   = 0
local OPT_BROWSE = 1
local OPT_LIST   = 2

dialog.register(798005, function(ctx, npc_eid, option_id)
    local gw = ctx.gateway_seq_id

    if option_id == 0 then
        dialog.send_window(gw, npc_eid,
            "Auction House Broker",
            "Welcome, Daeva. Browse current listings or register a new lot.",
            {
                { id = OPT_BROWSE, text = "Browse listings." },
                { id = OPT_LIST,   text = "Register an item for sale." },
                { id = OPT_EXIT,   text = "Farewell." },
            })

    elseif option_id == OPT_BROWSE then
        -- Client will send CM_AUCTION_SEARCH next; nothing server-side to
        -- prime. Closing the dialog window is fine.

    elseif option_id == OPT_LIST then
        -- Same as BROWSE: client opens the register UI on its own.

    elseif option_id == OPT_EXIT then
        -- no-op
    end
end)
