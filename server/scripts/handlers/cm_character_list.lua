-- scripts/handlers/cm_character_list.lua
-- CM_CHARACTER_LIST (0x11): client requests a character list refresh.
--
-- AION 5.8 sends this when the player clicks "Back" from character select,
-- or after deleting/restoring a character.
--
-- The actual SM_CHARACTER_LIST is built in Go (sendCharacterList) because it
-- requires SP calls and binary serialisation.  This handler just acknowledges
-- the request and logs it; the Go side will re-send the list on the next
-- player.enter event if needed.
--
-- For in-session refresh (without re-entering), we signal the world to resend.

register_handler(0x11, function(ctx, payload)
    log.info("CM_CHARACTER_LIST refresh requested by " .. tostring(ctx.account))
    -- TODO Phase S-3: trigger Go-side sendCharacterList via a world event
    -- For now the client will receive its list on the next reconnect.
end)
