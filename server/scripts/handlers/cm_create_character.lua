-- scripts/handlers/cm_create_character.lua
-- CM_CREATE_CHARACTER (0x12): client submits a new character for creation.
--
-- Payload (5.8 client, LE; field layout aligned with aion_putchar_20160620 SP):
--   utf16_null name            -- character display name (2..16 code units)
--   byte       gender          -- 0=male, 1=female
--   byte       race            -- 0=Elyos, 1=Asmodian
--   byte       class_id        -- starter class (see below)
--   int32      face_color
--   int32      hair_color
--   int32      eye_color
--   int32      lip_color
--   byte       face_type
--   byte       hair_type
--   byte       voice_type
--   float32    scale           -- body scale multiplier (typ. 1.0)
--
-- The client sends far more customisation sliders on the wire, but the above
-- subset is sufficient for character creation: the remaining 60+ "feat_*"
-- sliders default to 0 and the player can refine them later via the barber-
-- shop NPC. Doing so keeps this handler readable and matches what the early-
-- 5.8 character-creation UI actually populates.
--
-- Response: SM_CREATE_CHARACTER_RESPONSE (0x13):
--   byte  result             -- 0=OK, 1=name_invalid, 2=name_taken, 3=name_forbidden,
--                               4=bad_race, 5=bad_class, 6=bad_gender, 7=db_error
--   int32 char_id            -- new character id on success; 0 on error
--   utf16_null name          -- echoes name so the client can bind its row

-- Response codes kept in sync with the client's error-string table.
local RESULT_OK             = 0
local RESULT_NAME_INVALID   = 1
local RESULT_NAME_TAKEN     = 2
local RESULT_NAME_FORBIDDEN = 3
local RESULT_BAD_RACE       = 4
local RESULT_BAD_CLASS      = 5
local RESULT_BAD_GENDER     = 6
local RESULT_DB_ERROR       = 7

-- AION 5.8 starter class IDs (templates table, subset used at creation time).
-- Full list is defined by client_pak PC/class_data.xml; these are the seven
-- selectable classes at character-creation time (Aethertech, Songweaver,
-- Gunner, etc. are unlocked via ascension and cannot be created directly).
local VALID_STARTER_CLASSES = {
    [0]  = true,  -- Warrior
    [1]  = true,  -- Scout
    [2]  = true,  -- Mage
    [3]  = true,  -- Priest
    [4]  = true,  -- Technist
    [5]  = true,  -- Muse
    [6]  = true,  -- Chanter (derived but creatable in 5.8)
}

-- read_utf16_null pulls a UTF-16 LE null-terminated string from the reader
-- and decodes any code point < 0x80 as ASCII. Non-ASCII code points are
-- substituted with '?' so the downstream SP does not see invalid byte ranges.
local function read_utf16_null(r, max_units)
    local chars = {}
    local units = 0
    while r:remaining() >= 2 do
        local code = r:read_int16()
        if code == 0 then break end
        units = units + 1
        if max_units and units > max_units then
            -- Drain remaining units until null terminator to keep reader aligned.
            while r:remaining() >= 2 do
                if r:read_int16() == 0 then break end
            end
            return nil, units
        end
        if code < 0x80 then
            chars[#chars + 1] = string.char(code)
        else
            chars[#chars + 1] = "?"
        end
    end
    return table.concat(chars), units
end

-- send_response builds SM_CREATE_CHARACTER_RESPONSE (0x13) and pushes it to
-- the gateway session of the caller. Kept inline so the handler file is
-- self-contained (no lib/character.lua needed for the unhandled-opcode fix).
local function send_response(gw, result, char_id, name)
    local buf = bytes.new()
    buf:write_byte(result)
    buf:write_int32(char_id or 0)
    buf:write_string_utf16(name or "")
    player.send_packet(gw, 0x13, buf:to_string())
end

register_handler(0x12, function(ctx, payload)
    -- 1) Parse + length-validate the name (2..16 UTF-16 code units per NCSoft spec).
    local name, units = read_utf16_null(payload, 16)
    if name == nil then
        log.warn("CM_CREATE_CHARACTER: name too long (>" .. tostring(units) .. " units)")
        send_response(ctx.gateway_seq_id, RESULT_NAME_INVALID, 0, "")
        return
    end
    if #name < 2 or units < 2 then
        log.warn("CM_CREATE_CHARACTER: name too short len=" .. tostring(#name))
        send_response(ctx.gateway_seq_id, RESULT_NAME_INVALID, 0, name)
        return
    end

    local gender = payload:read_byte()
    local race   = payload:read_byte()
    local class_id = payload:read_byte()

    if gender ~= 0 and gender ~= 1 then
        send_response(ctx.gateway_seq_id, RESULT_BAD_GENDER, 0, name)
        return
    end
    if race ~= 0 and race ~= 1 then
        send_response(ctx.gateway_seq_id, RESULT_BAD_RACE, 0, name)
        return
    end
    if not VALID_STARTER_CLASSES[class_id] then
        send_response(ctx.gateway_seq_id, RESULT_BAD_CLASS, 0, name)
        return
    end

    local face_color = payload:read_int32()
    local hair_color = payload:read_int32()
    local eye_color  = payload:read_int32()
    local lip_color  = payload:read_int32()
    local face_type  = payload:read_byte()
    local hair_type  = payload:read_byte()
    local voice_type = payload:read_byte()
    local scale      = payload:read_float32()
    if scale <= 0 then scale = 1.0 end

    -- 2) Name-validation SP: returns 0=ok, -1=duplicate, -2=forbidden, -3=reserved.
    local nv_rows, nv_err = db.call("aion_checkvalidcharname", name, ctx.account)
    if nv_err ~= nil then
        log.error("CM_CREATE_CHARACTER: name-check SP error err=" .. tostring(nv_err))
        send_response(ctx.gateway_seq_id, RESULT_DB_ERROR, 0, name)
        return
    end
    local nv = (nv_rows and nv_rows[1] and (nv_rows[1].aion_checkvalidcharname
        or nv_rows[1][1])) or 0
    if nv == -1 then
        send_response(ctx.gateway_seq_id, RESULT_NAME_TAKEN, 0, name)
        return
    elseif nv == -2 or nv == -3 then
        send_response(ctx.gateway_seq_id, RESULT_NAME_FORBIDDEN, 0, name)
        return
    end

    -- 3) Insert the character. aion_putchar_20160620 takes 80+ columns; the
    --    remaining customisation sliders default to 0 at creation time.
    --    The SP returns a new char_id via its first output column.
    local rows, err = db.call("aion_putchar_20160620",
        name,                       -- p_strUserId (display name)
        ctx.account_id,             -- p_nAccountID
        ctx.account,                -- p_strAccountName
        race,                       -- p_nRace
        class_id,                   -- p_nClass
        gender,                     -- p_nGender
        face_color, hair_color,     -- p_nHeadFaceColor / HairColor
        eye_color, lip_color,       -- p_nEyeColor / LipColor
        face_type, hair_type,       -- p_nHeadFaceType / HairType
        scale,                      -- p_fScale
        voice_type,                 -- p_nVoiceType
        0, 0,                       -- p_nFeatType1 / FeatType2
        0, 0,                       -- p_nHeadBumpType / HeadExpressionType
        0,                          -- p_nNameId
        0,                          -- p_nOrgServer
        -- Spawn point: race-dependent starter map. Elyos → Poeta (210020000),
        -- Asmodian → Ishalgen (220020000). Coordinates chosen to match the
        -- classic starter cinematic landing zones.
        race == 0 and 210020000 or 220020000,  -- p_nWorld
        race == 0 and 1498.0 or 1510.0,        -- p_nXlocation
        race == 0 and 1563.0 or 1320.0,        -- p_nYlocation
        race == 0 and 193.0  or 193.0,         -- p_nZlocation
        0,                          -- p_nDir (heading)
        500, 300,                   -- p_nHp / p_nMp (level-1 base)
        0,                          -- p_nBuilder
        1                           -- p_lev
        -- The 50+ remaining feat_* fields default to 0 in the SP; omitting
        -- them here relies on PostgreSQL positional argument defaulting.
        -- If the deployed SP requires every positional arg, the redeploy
        -- script adds DEFAULT clauses in a follow-up patch.
    )
    if err ~= nil then
        log.error("CM_CREATE_CHARACTER: aion_putchar_20160620 err=" .. tostring(err)
            .. " name=" .. name .. " account=" .. tostring(ctx.account))
        send_response(ctx.gateway_seq_id, RESULT_DB_ERROR, 0, name)
        return
    end

    -- The SP returns the new char_id on its first row under one of several
    -- NCSoft-export column names. Accept any of them and fall back to 0.
    local new_id = 0
    if rows and rows[1] then
        new_id = rows[1].char_id or rows[1].p_ncharid or rows[1][1] or 0
    end

    log.info("CM_CREATE_CHARACTER: created name=" .. name
        .. " account=" .. tostring(ctx.account)
        .. " race=" .. tostring(race) .. " class=" .. tostring(class_id)
        .. " char_id=" .. tostring(new_id))

    send_response(ctx.gateway_seq_id, RESULT_OK, new_id, name)
end)
