-- scripts/lib/chat.lua
-- Chat channel routing and SM_CHAT (0x48) packet construction.
--
-- SM_CHAT payload (LE, unverified — matches player.send_message format):
--   byte          channel
--   utf16_null    sender_name
--   utf16_null    message
--
-- Channel constants follow NCSoft AION convention (values unverified;
-- adjust after packet capture).
--
-- Usage (from cm_chat.lua handler):
--   chat.broadcast_local(sender_eid, sender_name, msg)   -- 25m radius
--   chat.broadcast_shout(sender_eid, sender_name, msg)   -- 100m radius
--   chat.send_whisper(sender_name, target_name, msg)     -- private
--   chat.send_system(gateway_seq_id, msg)                -- GM/system -> player

chat = {}

-- Channel byte constants (client-facing).
chat.CH_NORMAL = 0x00  -- local area, 25 m
chat.CH_SHOUT  = 0x01  -- region, 100 m
chat.CH_WHISPER = 0x02 -- private 1-on-1
chat.CH_GROUP  = 0x03  -- party
chat.CH_LEGION = 0x04  -- guild
chat.CH_WORLD  = 0x05  -- reserved (cash-shop item)
chat.CH_SYSTEM = 0x0B  -- server notice (same byte as player.send_message)

-- Broadcast radii in metres.
local LOCAL_RANGE = 25.0
local SHOUT_RANGE = 100.0

-- --------------------------------------------------------
-- build_packet(channel, sender_name, message) -> binary string
-- Constructs the SM_CHAT payload once so it can be reused for every recipient.
-- --------------------------------------------------------
local function build_packet(channel, sender_name, message)
    local buf = bytes.new()
    buf:write_byte(channel)
    buf:write_string_utf16(sender_name or "")
    buf:write_string_utf16(message or "")
    return buf:to_string()
end

-- --------------------------------------------------------
-- chat.broadcast_local(sender_eid, sender_name, message)
-- Sends NORMAL channel to sender + all players within 25 m.
-- --------------------------------------------------------
chat.broadcast_local = function(sender_eid, sender_name, message)
    local pkt = build_packet(chat.CH_NORMAL, sender_name, message)

    -- Include the sender (echo).
    local sgw = entity.get_gateway_id(sender_eid)
    if sgw then player.send_packet(sgw, 0x48, pkt) end

    for _, eid in ipairs(entity.get_nearby_players(sender_eid, LOCAL_RANGE)) do
        local gw = entity.get_gateway_id(eid)
        if gw then player.send_packet(gw, 0x48, pkt) end
    end
end

-- --------------------------------------------------------
-- chat.broadcast_shout(sender_eid, sender_name, message)
-- Sends SHOUT channel to sender + all players within 100 m.
-- --------------------------------------------------------
chat.broadcast_shout = function(sender_eid, sender_name, message)
    local pkt = build_packet(chat.CH_SHOUT, sender_name, message)

    local sgw = entity.get_gateway_id(sender_eid)
    if sgw then player.send_packet(sgw, 0x48, pkt) end

    for _, eid in ipairs(entity.get_nearby_players(sender_eid, SHOUT_RANGE)) do
        local gw = entity.get_gateway_id(eid)
        if gw then player.send_packet(gw, 0x48, pkt) end
    end
end

-- --------------------------------------------------------
-- chat.send_whisper(sender_name, target_name, message) -> bool
-- Resolves target by name; returns true on delivery, false if target offline.
-- Echoes to sender on success so their own chat window shows the whisper.
-- --------------------------------------------------------
chat.send_whisper = function(sender_name, target_name, message)
    local target_eid = player.find_by_name(target_name)
    if target_eid == 0 then
        return false
    end

    local tgw = entity.get_gateway_id(target_eid)
    if not tgw then
        return false
    end

    local pkt = build_packet(chat.CH_WHISPER, sender_name, message)
    player.send_packet(tgw, 0x48, pkt)

    -- Echo to sender so their UI shows the outgoing whisper.
    local sender_eid = player.find_by_name(sender_name)
    if sender_eid ~= 0 then
        local sgw = entity.get_gateway_id(sender_eid)
        if sgw then player.send_packet(sgw, 0x48, pkt) end
    end

    return true
end

-- --------------------------------------------------------
-- chat.broadcast_group(member_gws, sender_name, message)
-- Sends GROUP channel to all gateway ids in member_gws.
-- member_gws: array of gateway_seq_id values (from group.lua).
-- --------------------------------------------------------
chat.broadcast_group = function(member_gws, sender_name, message)
    local pkt = build_packet(chat.CH_GROUP, sender_name, message)
    for _, gw in ipairs(member_gws or {}) do
        player.send_packet(gw, 0x48, pkt)
    end
end

-- --------------------------------------------------------
-- chat.send_system(gateway_seq_id, message)
-- Sends a SYSTEM-channel notice to a single player. Thin wrapper over
-- player.send_message with the same byte layout.
-- --------------------------------------------------------
chat.send_system = function(gateway_seq_id, message)
    local pkt = build_packet(chat.CH_SYSTEM, "", message)
    player.send_packet(gateway_seq_id, 0x48, pkt)
end
