-- scripts/handlers/cm_chat.lua
-- CM_CHAT (0x46): client sends a chat message.
--
-- Payload (LE, unverified):
--   byte        channel     -- see chat.CH_*
--   utf16_null  target_name -- only for WHISPER; empty otherwise
--   utf16_null  message
--
-- Routes to the appropriate chat.* broadcast based on channel byte.
-- Anti-spam: 1 message per second per player, enforced via ECS "chat_last_tick".

local CHAT_INTERVAL_TICKS = 20 -- 1 second at 20 Hz tick rate

-- Helper: read a UTF-16 LE null-terminated string from a payload reader.
-- gopher-lua bytes.reader exposes read_byte/read_int16; we consume int16 words
-- until 0x0000 and decode to ASCII (sufficient for unit tests / dev).
local function read_utf16_null(r)
    local chars = {}
    while r:remaining() >= 2 do
        local code = r:read_int16()
        if code == 0 then
            break
        end
        -- BMP-only decode: 0-127 to single byte, >127 becomes '?' for now.
        if code < 0x80 then
            chars[#chars + 1] = string.char(code)
        else
            chars[#chars + 1] = "?"
        end
    end
    return table.concat(chars)
end

register_handler(0x46, function(ctx, payload)
    -- Dead entities cannot chat (prevents death-screen spam).
    if entity.get_stat(ctx.entity_id, "dead") > 0 then
        return
    end

    -- Throttle: reject if within CHAT_INTERVAL_TICKS of previous message.
    local last = entity.get_stat(ctx.entity_id, "chat_last_tick")
    if current_tick and last and (current_tick - last) < CHAT_INTERVAL_TICKS then
        log.info("CM_CHAT: throttled entity=" .. tostring(ctx.entity_id))
        return
    end

    local channel     = payload:read_byte()
    local target_name = read_utf16_null(payload)
    local message     = read_utf16_null(payload)

    if message == "" then
        return
    end

    -- Resolve sender's display name from ECS.
    local sender_name = player.get_name(ctx.gateway_seq_id)
    if sender_name == "" then
        sender_name = "?"
    end

    -- Record throttle timestamp AFTER successful parse.
    if current_tick then
        entity.set_stat(ctx.entity_id, "chat_last_tick", current_tick)
    end

    if channel == chat.CH_NORMAL then
        chat.broadcast_local(ctx.entity_id, sender_name, message)

    elseif channel == chat.CH_SHOUT then
        chat.broadcast_shout(ctx.entity_id, sender_name, message)

    elseif channel == chat.CH_WHISPER then
        if target_name == "" then
            return
        end
        local ok = chat.send_whisper(sender_name, target_name, message)
        if not ok then
            chat.send_system(ctx.gateway_seq_id,
                "User '" .. target_name .. "' is not online.")
        end

    elseif channel == chat.CH_GROUP then
        if group then
            local gws = group.member_gateways(ctx.entity_id)
            if gws and #gws > 0 then
                chat.broadcast_group(gws, sender_name, message)
            else
                chat.send_system(ctx.gateway_seq_id, "You are not in a group.")
            end
        end

    elseif channel == chat.CH_LEGION then
        -- Legion chat is funneled through chat.broadcast_group (same byte
        -- layout as group) but using the legion's gateway list. Reusing the
        -- group broadcast helper avoids duplicating the packet-build path.
        if legion then
            local gws = legion.member_gateways(ctx.entity_id)
            if gws and #gws > 0 then
                -- Build a CH_LEGION-tagged packet inline so it reads correctly
                -- on clients even though we reuse broadcast_group's iteration.
                local buf = bytes.new()
                buf:write_byte(chat.CH_LEGION)
                buf:write_string_utf16(sender_name)
                buf:write_string_utf16(message)
                local pkt = buf:to_string()
                for _, gw in ipairs(gws) do
                    player.send_packet(gw, 0x48, pkt)
                end
            else
                chat.send_system(ctx.gateway_seq_id, "You are not in a legion.")
            end
        end

    else
        log.warn("CM_CHAT: unsupported channel=" .. tostring(channel))
    end

    log.info("CM_CHAT ch=" .. tostring(channel)
        .. " sender=" .. sender_name
        .. " msg=\"" .. message .. "\"")
end)
