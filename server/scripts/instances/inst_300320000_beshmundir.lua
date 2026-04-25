-- scripts/instances/inst_300320000_beshmundir.lua
-- Beshmundir Temple (end-game 6-man group, lv55).
--
-- NCSoft's iconic 3.0-era group instance at WorldID 300320000. Serves as the
-- canonical 6-man-instance demo for Phase S-19. Cooldown and validity values
-- follow the live-service 2014-era tuning (18h cooldown, 2h validity). The
-- boss (Stormwing) drops a sizeable kinah reward plus one unique weapon
-- token; multi-boss scripting is deferred to a Phase S-20+ DSL.

instance.register({
    template_id     = 300320000,
    display_name    = "Beshmundir Temple",
    world_id        = 300320000,

    min_level       = 55,
    max_level       = 66,            -- level cap of 5.8 era
    min_members     = 2,             -- requires a real party (not solo)
    max_members     = 6,

    reentrance_sec  = 3600 * 18,     -- 18h cooldown between full clears
    validity_hours  = 2,
    reset_fee_kinah = 200000,        -- 200k kinah per reset

    spawn_x = 256.0, spawn_y = 256.0, spawn_z = 100.0,
    boss_template = 217205,          -- Stormwing (placeholder)
    boss_x = 300.0, boss_y = 300.0, boss_z = 100.0,

    rewards = {
        kinah = 250000,
        -- Single-roll unique drop for the group (MVP: everyone gets one;
        -- per-player roll mechanics deferred).
        items = { { id = 100100501, count = 1 } },
    },

    on_boss_kill = function(inst, boss_eid)
        -- Custom post-clear hook: broadcast a grand announcement to all
        -- members so the group UI can render a clear-banner. Uses the chat
        -- system channel since the S-19 client-side boss-clear banner is not
        -- yet wired.
        if not chat or not chat.send_system then return end
        for _, m in ipairs(inst.members) do
            local gw = entity.get_gateway_id(m)
            if gw then
                chat.send_system(gw,
                    "Beshmundir Temple cleared! Stormwing has fallen.")
            end
        end
    end,
})
