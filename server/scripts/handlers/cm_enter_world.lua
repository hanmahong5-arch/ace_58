-- scripts/handlers/cm_enter_world.lua
-- CM_ENTER_WORLD (0x15): client confirms the character to enter the world with.
--
-- Payload (binary, little-endian):
--   int32  char_id  -- Selected character ID
--
-- Phase S-3: loads position and core stats from DB via aion_GetCharInfo_20160818,
-- updates the ECS entity, then sends SM_ENTER_WORLD_RESPONSE (0x16).

register_handler(0x15, function(ctx, payload)
    local char_id = payload:read_int32()

    log.info("CM_ENTER_WORLD account=" .. tostring(ctx.account)
        .. " char_id=" .. tostring(char_id))

    -- Fetch character data from the stored procedure.
    local rows, err = db.call("aion_GetCharInfo_20160818", char_id)
    if err ~= nil then
        log.warn("CM_ENTER_WORLD: DB error char_id=" .. tostring(char_id)
            .. " err=" .. tostring(err))
        return
    end
    if not rows or #rows == 0 then
        log.warn("CM_ENTER_WORLD: char not found char_id=" .. tostring(char_id))
        return
    end
    local info = rows[1]

    -- Set world position in ECS (x, y, z, heading).
    local x       = info.xlocation or 0
    local y       = info.ylocation or 0
    local z       = info.zlocation or 0
    local heading = info.dir       or 0
    entity.set_position(ctx.entity_id, x, y, z, heading)

    -- Cache frequently-read stats in ECS for O(1) access during gameplay.
    entity.set_stat(ctx.entity_id, "char_id",  char_id)
    entity.set_stat(ctx.entity_id, "level",    info.lev        or 1)
    entity.set_stat(ctx.entity_id, "hp",       info.now_hit    or 100)
    entity.set_stat(ctx.entity_id, "mp",       info.now_mana   or 100)
    entity.set_stat(ctx.entity_id, "fp",       info.now_flight or 100)
    -- Max stats are required for regen (Phase S-4).
    -- Column names are NCSoft convention; fall back to sensible defaults if absent.
    entity.set_stat(ctx.entity_id, "max_hp",   info.max_hit    or info.now_hit    or 1000)
    entity.set_stat(ctx.entity_id, "max_mp",   info.max_mana   or info.now_mana   or 1000)
    entity.set_stat(ctx.entity_id, "max_fp",   info.max_flight or info.now_flight or 6000)
    entity.set_stat(ctx.entity_id, "world_id", info.world      or 0)
    entity.set_stat(ctx.entity_id, "map_num",  info.world_map_number or 0)

    -- Phase S-11: PvP faction + abyss-point hydration.
    -- NCSoft schema stores the race on varying column names across exports:
    -- accept "race", "race_id", or "racetype" (in priority order). Value is
    -- 0=Elyos, 1=Asmodian; anything else defaults to 0 (Elyos).
    local race = info.race or info.race_id or info.racetype or 0
    if race ~= 0 and race ~= 1 then
        race = 0
    end
    entity.set_stat(ctx.entity_id, "faction", race)
    entity.set_stat(ctx.entity_id, "pvp_flag", 0)

    -- abyss_points: prefer the value on the enter-world row if present,
    -- otherwise try the dedicated SP. Either missing path leaves the stat at 0.
    local ap = info.abyss_point or info.abysspoint or info.ap or 0
    if ap == 0 and db then
        local ap_rows, ap_err = db.call("aion_GetAbyssPointUser", char_id)
        if not ap_err and ap_rows and #ap_rows > 0 then
            ap = ap_rows[1].abyss_point or ap_rows[1].ap or 0
        end
    end
    entity.set_stat(ctx.entity_id, "abyss_points", ap)

    -- Phase S-7: populate CharName for whisper / group / chat routing.
    -- NCSoft column name is typically "name"; fall back to "char_name" variant.
    local char_name = info.name or info.char_name or ""
    if char_name ~= "" then
        player.set_name(ctx.gateway_seq_id, char_name)
    end

    -- Phase S-10: rehydrate legion membership so legion chat, MOTD, and
    -- rank checks all work immediately on re-login. load_from_db is a no-op
    -- when the player is already cached by another online legion member.
    if legion then
        local leg = legion.load_from_db(ctx.entity_id)
        if leg then
            log.info("CM_ENTER_WORLD: legion loaded id=" .. tostring(leg.id)
                .. " name=" .. tostring(leg.name))
        end
    end

    -- Build SM_ENTER_WORLD_RESPONSE (0x16) payload.
    local buf = bytes.new()
    buf:write_byte(0)                              -- result: 0 = success
    buf:write_int32(char_id)
    buf:write_int32(info.world             or 0)   -- world_id
    buf:write_int32(info.world_map_number  or 0)   -- map_num
    buf:write_float32(x)
    buf:write_float32(y)
    buf:write_float32(z)
    buf:write_byte(heading)

    player.send_packet(ctx.gateway_seq_id, 0x16, buf:to_string())

    -- Send SM_INVENTORY_INFO (0x54): populate client inventory UI.
    -- Format (LE, unverified — minimal subset; adjust after packet capture):
    --   int32 count, then for each item: int32 item_id, int32 item_count, int32 slot
    -- Phase S-12: rows with equip_slot_position > 0 are auto-equipped by
    --   equipment.equip after the inventory packet is sent, so stat bonuses
    --   are live before the first movement tick.
    -- WARNING: shadows the "items" global (scripts/lib/items.lua) within this
    -- block. Use `inv_items` to avoid clobbering the item-template registry.
    local inv_items = player.get_inventory(ctx.gateway_seq_id)
    if inv_items and #inv_items > 0 then
        local inv_buf = bytes.new()
        inv_buf:write_int32(#inv_items)
        for _, it in ipairs(inv_items) do
            inv_buf:write_int32(it.item_id             or 0)
            inv_buf:write_int32(it.item_count          or 1)
            inv_buf:write_int32(it.equip_slot_position or 0)
        end
        player.send_packet(ctx.gateway_seq_id, 0x54, inv_buf:to_string())
        log.info("CM_ENTER_WORLD: sent inventory count=" .. tostring(#inv_items))

        if equipment then
            local equipped = 0
            for _, it in ipairs(inv_items) do
                if (it.equip_slot_position or 0) > 0 and it.item_id then
                    local ok = equipment.equip(ctx.entity_id, it.item_id)
                    if ok then equipped = equipped + 1 end
                end
            end
            if equipped > 0 then
                log.info("CM_ENTER_WORLD: auto-equipped "
                    .. tostring(equipped) .. " items")
            end
        end
    end

    log.info("CM_ENTER_WORLD: world entry success"
        .. " account=" .. tostring(ctx.account)
        .. " world="   .. tostring(info.world)
        .. " pos=("    .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. ")")
end)
