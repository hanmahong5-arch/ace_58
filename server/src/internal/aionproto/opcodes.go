// Package aionproto defines AION 5.8 packet types, codec, and opcode constants.
//
// Packet wire format (all integers little-endian):
//
//	Offset  Len  Field
//	0       2    Total packet length (includes this header; minimum 3)
//	2       2    Opcode (uint16 LE for game packets; uint8 for auth packets)
//	4+      var  Packet-specific payload
//
// Packets are BF-LE encrypted starting at byte 2 (opcode + payload).
// XOR stream cipher is applied on top of BF decryption for client→server.
package aionproto

// Auth port (:2108) opcodes — exchanged during login handshake.
const (
	// SM_KEY is the first packet sent by the server, unencrypted.
	// Contains RSA public key modulus and the static Blowfish key.
	SM_KEY uint16 = 0x00

	// CM_AUTH_LOGIN is sent by the client with RSA-encrypted credentials.
	CM_AUTH_LOGIN uint16 = 0x01

	// SM_LOGIN_OK confirms successful authentication and carries server list.
	SM_LOGIN_OK uint16 = 0x02

	// SM_LOGIN_FAIL carries an error code when authentication fails.
	SM_LOGIN_FAIL uint16 = 0x03

	// CM_PLAY is sent by the client to select a game server from the list.
	CM_PLAY uint16 = 0x05

	// SM_PLAY_OK carries the session token for game server entry.
	SM_PLAY_OK uint16 = 0x06

	// SM_PLAY_FAIL is sent when CM_PLAY cannot be serviced.
	SM_PLAY_FAIL uint16 = 0x07
)

// Game port (:7777) opcodes — exchanged during gameplay after login.
const (
	// CM_VERSION_CHECK is the first client packet on the game connection.
	CM_VERSION_CHECK uint16 = 0x0B

	// SM_VERSION_CHECK_OK confirms the client version is accepted.
	SM_VERSION_CHECK_OK uint16 = 0x0C

	// SM_SESSION_KEY carries the session-specific BF key for the game session.
	SM_SESSION_KEY uint16 = 0x1A

	// CM_SESSION_CONFIRM carries the session token from the auth server.
	CM_SESSION_CONFIRM uint16 = 0x1B

	// SM_CHARACTER_LIST carries the list of characters on the account.
	SM_CHARACTER_LIST uint16 = 0x10

	// CM_CHARACTER_LIST requests the character list.
	CM_CHARACTER_LIST uint16 = 0x11

	// CM_CREATE_CHARACTER requests character creation.
	CM_CREATE_CHARACTER uint16 = 0x12

	// SM_CREATE_CHARACTER_RESPONSE carries the creation result.
	SM_CREATE_CHARACTER_RESPONSE uint16 = 0x13

	// CM_DELETE_CHARACTER requests character deletion.
	CM_DELETE_CHARACTER uint16 = 0x14

	// SM_DELETE_CHARACTER_RESPONSE carries the deletion result (Phase S-18b).
	// Sent in reply to CM_DELETE_CHARACTER (0x14). AION 5.8 uses a soft-delete
	// 7-day grace window; the client shows the character with a countdown.
	SM_DELETE_CHARACTER_RESPONSE uint16 = 0x17

	// CM_ENTER_WORLD requests world entry with a selected character.
	CM_ENTER_WORLD uint16 = 0x15

	// SM_ENTER_WORLD_RESPONSE carries entry result and initial world state.
	SM_ENTER_WORLD_RESPONSE uint16 = 0x16

	// CM_MOVE carries client movement updates.
	CM_MOVE uint16 = 0x0A

	// SM_MOVE broadcasts a player's movement to nearby clients.
	SM_MOVE uint16 = 0x4C

	// CM_ATTACK carries a melee attack request.
	CM_ATTACK uint16 = 0x2C

	// SM_ATTACK broadcasts an attack result.
	SM_ATTACK uint16 = 0x8E

	// CM_USE_SKILL carries a skill cast request.
	CM_USE_SKILL uint16 = 0x0E

	// SM_SKILL_RESULT broadcasts skill cast result.
	SM_SKILL_RESULT uint16 = 0x5E

	// SM_DIE notifies clients of an entity death.
	SM_DIE uint16 = 0x44

	// CM_EMOTION carries emote/idle animation.
	CM_EMOTION uint16 = 0x41

	// CM_CHAT carries a chat message.
	CM_CHAT uint16 = 0x46

	// SM_CHAT broadcasts a chat message.
	SM_CHAT uint16 = 0x48

	// SM_PLAYER_INFO carries detailed player information.
	SM_PLAYER_INFO uint16 = 0x34

	// SM_STAT_INFO carries player stats update.
	SM_STAT_INFO uint16 = 0x1E

	// SM_INVENTORY_INFO carries initial inventory state.
	SM_INVENTORY_INFO uint16 = 0x54

	// CM_REVIVE_REQUEST is sent by the client to resurrect the character at bind point.
	CM_REVIVE_REQUEST uint16 = 0x56

	// SM_BUFF_INFO notifies the client and nearby players that a buff was applied.
	// NOTE: wire format unverified; adjust after packet capture.
	SM_BUFF_INFO uint16 = 0x3C

	// SM_SKILL_FAILED notifies the client that a skill cast was rejected.
	// Reason byte: 1=cooldown, 2=no_mp, 3=range, 4=unknown.
	// NOTE: opcode and format unverified; adjust after packet capture.
	SM_SKILL_FAILED uint16 = 0x90

	// SM_REVIVE notifies the client that resurrection was successful.
	SM_REVIVE uint16 = 0x7A

	// SM_EXP_UPDATE notifies the client of an experience point change.
	// NOTE: wire format unverified; adjust after packet capture.
	SM_EXP_UPDATE uint16 = 0x19

	// SM_LEVEL_UP notifies the client and nearby players of a character level increase.
	// NOTE: wire format unverified; adjust after packet capture.
	SM_LEVEL_UP uint16 = 0x9D

	// CM_LOGOUT requests character logout.
	CM_LOGOUT uint16 = 0xAB

	// CM_GROUP_INVITE is sent by the leader to invite another player to a party.
	// NOTE: opcode and payload format unverified; adjust after packet capture.
	CM_GROUP_INVITE uint16 = 0x60

	// CM_GROUP_ACCEPT is sent by the invitee to accept a pending party invitation.
	CM_GROUP_ACCEPT uint16 = 0x61

	// CM_GROUP_LEAVE is sent when a player voluntarily leaves their current party.
	CM_GROUP_LEAVE uint16 = 0x62

	// SM_GROUP_INFO carries the full party roster (leader + members) to a client.
	SM_GROUP_INFO uint16 = 0x63

	// SM_GROUP_MEMBER_UPDATE notifies all party members of a single member's
	// HP/MP/level change. Sent by the on_tick group sync loop.
	SM_GROUP_MEMBER_UPDATE uint16 = 0x64

	// CM_DIALOG_REQUEST is sent when the client right-clicks / interacts with
	// an NPC. The server responds with SM_DIALOG_WINDOW carrying a dialog tree.
	// NOTE: opcode and payload format unverified; adjust after packet capture.
	CM_DIALOG_REQUEST uint16 = 0x6A

	// CM_DIALOG_SELECT is sent when the player picks an option from a dialog.
	CM_DIALOG_SELECT uint16 = 0x6B

	// CM_BUY_ITEM is sent to purchase an item from an open vendor dialog.
	CM_BUY_ITEM uint16 = 0x6C

	// CM_SELL_ITEM is sent to sell an inventory item back to a vendor.
	CM_SELL_ITEM uint16 = 0x6D

	// CM_TELEPORT is sent when the player confirms a teleport destination
	// from a Gatekeeper's dialog menu.
	CM_TELEPORT uint16 = 0x6E

	// SM_DIALOG_WINDOW carries the NPC dialog title, body text, and option list
	// for the client to render a dialog UI.
	SM_DIALOG_WINDOW uint16 = 0x6F

	// SM_TELEPORT_LOC notifies the client and nearby players that an entity
	// has been relocated (used for teleport-effect rendering).
	SM_TELEPORT_LOC uint16 = 0x70

	// CM_FLIGHT_TOGGLE is sent when the player presses the flight hotkey
	// (toggles ground ↔ flying). Server validates that the zone permits flight.
	// NOTE: opcode and payload format unverified; adjust after packet capture.
	CM_FLIGHT_TOGGLE uint16 = 0x71

	// CM_GLIDE_START is sent when the player begins gliding (falling from
	// height while holding the glide key). Drains FP slower than full flight.
	CM_GLIDE_START uint16 = 0x72

	// CM_GLIDE_END is sent when the player stops gliding (lands or transitions
	// to full flight).
	CM_GLIDE_END uint16 = 0x73

	// SM_FLY_STATE broadcasts a player's flight state change (ground/glide/fly)
	// to observers within render range so their clients update the animation.
	SM_FLY_STATE uint16 = 0x74

	// CM_FLIGHT_PATH_SELECT is sent when the player picks a destination from
	// a Flight Master's dialog menu. Triggers an automated flight-path arc.
	CM_FLIGHT_PATH_SELECT uint16 = 0x75

	// SM_FLIGHT_PATH_START notifies the client to begin the scripted
	// flight-path cinematic to the chosen destination.
	SM_FLIGHT_PATH_START uint16 = 0x76

	// Legion (guild) opcodes — Phase S-10.
	// 0x77 collides with nothing; 0x7A is already SM_REVIVE so we jump to 0xB0.
	// NOTE: all legion opcodes and payload formats are unverified; adjust
	// after packet capture against the 5.8 client.

	// CM_LEGION_CREATE is sent by a player to found a new legion (guild).
	// Payload: utf16_null legion_name. Server validates name + 100k kinah fee.
	CM_LEGION_CREATE uint16 = 0xB0

	// CM_LEGION_INVITE is sent by the brigade general or centurion to invite
	// another online player into their legion.
	// Payload: utf16_null target_char_name.
	CM_LEGION_INVITE uint16 = 0xB1

	// CM_LEGION_ACCEPT is sent by the invitee to accept a pending invitation.
	CM_LEGION_ACCEPT uint16 = 0xB2

	// CM_LEGION_LEAVE is sent by a member to voluntarily leave their legion.
	CM_LEGION_LEAVE uint16 = 0xB3

	// CM_LEGION_KICK is sent by the brigade general to expel a member.
	// Payload: utf16_null target_char_name.
	CM_LEGION_KICK uint16 = 0xB4

	// CM_LEGION_MOTD is sent by an officer to set the legion's message of the day.
	// Payload: utf16_null motd (max 256 UTF-16 code units).
	CM_LEGION_MOTD uint16 = 0xB5

	// SM_LEGION_INFO carries the full legion roster and metadata to a client.
	// Emitted on login, on member join/leave, and on MOTD change.
	SM_LEGION_INFO uint16 = 0xB6

	// SM_LEGION_MEMBER_UPDATE notifies all online members of a single member's
	// rank change or online/offline transition.
	SM_LEGION_MEMBER_UPDATE uint16 = 0xB7

	// PvP / Abyss opcodes — Phase S-11.
	// NOTE: opcodes and payload formats unverified; adjust after packet capture.

	// CM_PVP_FLAG_TOGGLE is sent when the player toggles their PvP participation
	// flag. While flagged, same-faction players may damage each other (duel mode).
	CM_PVP_FLAG_TOGGLE uint16 = 0xB8

	// SM_PVP_FLAG broadcasts an entity's PvP-flag change to nearby observers so
	// their clients update the name-plate coloring.
	// Payload (LE): int32 entity_id, byte is_flagged.
	SM_PVP_FLAG uint16 = 0xB9

	// SM_ABYSS_POINT_UPDATE notifies a client that its abyss-point balance
	// changed (e.g. after a PvP kill or faction reward).
	// Payload (LE): int64 new_total, int64 delta.
	SM_ABYSS_POINT_UPDATE uint16 = 0xBA

	// Equipment opcodes — Phase S-12.
	// NOTE: opcodes and payload formats unverified; adjust after packet capture.

	// CM_EQUIP_ITEM is sent when the player equips an item from their inventory
	// into a specific equipment slot.
	// Payload (LE): int32 item_id, byte slot.
	CM_EQUIP_ITEM uint16 = 0xBB

	// CM_UNEQUIP_ITEM is sent when the player removes an item from an
	// equipment slot back into the inventory.
	// Payload (LE): byte slot.
	CM_UNEQUIP_ITEM uint16 = 0xBC

	// SM_EQUIPMENT_CHANGED broadcasts an entity's slot change so nearby
	// observers update their rendering of the character model.
	// Payload (LE): int32 entity_id, byte slot, int32 item_id (0 = unequipped).
	SM_EQUIPMENT_CHANGED uint16 = 0xBD

	// Mail opcodes — Phase S-14.
	// NOTE: opcodes and payload formats unverified; adjust after packet capture.

	// CM_MAIL_SEND is sent by the client to compose and send an in-game mail.
	// Payload (LE): utf16_null recipient_name, utf16_null subject, utf16_null body,
	//   int32 attached_item_id (0=none), int32 attached_item_count,
	//   int64 attached_kinah.
	CM_MAIL_SEND uint16 = 0xBE

	// CM_MAIL_LIST requests the player's inbox.
	// Payload: empty.
	CM_MAIL_LIST uint16 = 0xBF

	// CM_MAIL_READ marks a mail as read and returns its full body.
	// Payload (LE): int64 mail_id.
	CM_MAIL_READ uint16 = 0xC0

	// CM_MAIL_CLAIM takes the attached item and/or kinah from a mail.
	// Payload (LE): int64 mail_id.
	CM_MAIL_CLAIM uint16 = 0xC1

	// CM_MAIL_DELETE permanently removes a mail from the inbox.
	// Payload (LE): int64 mail_id.
	CM_MAIL_DELETE uint16 = 0xC2

	// SM_MAIL_LIST carries the mail list response. Payload (LE):
	//   int32 count, then for each mail: int64 mail_id, utf16_null sender_name,
	//   utf16_null subject, byte is_read, byte has_attachment,
	//   int64 sent_timestamp_unix.
	SM_MAIL_LIST uint16 = 0xC3

	// SM_MAIL_NEW notifies the recipient that a new mail arrived. Payload (LE):
	//   int64 mail_id, utf16_null sender_name, utf16_null subject.
	SM_MAIL_NEW uint16 = 0xC4

	// Warehouse opcodes — Phase S-15.
	// NOTE: opcodes and payload formats unverified; adjust after packet capture.

	// CM_WAREHOUSE_LIST requests the player's warehouse contents. Sent after
	// the client opens a Warehouse Keeper dialog.
	// Payload: empty.
	CM_WAREHOUSE_LIST uint16 = 0xC5

	// CM_WAREHOUSE_DEPOSIT moves an item from inventory into the warehouse.
	// Payload (LE): int32 item_id, int32 count.
	CM_WAREHOUSE_DEPOSIT uint16 = 0xC6

	// CM_WAREHOUSE_WITHDRAW moves an item from the warehouse into inventory.
	// Payload (LE): int32 item_id, int32 count.
	CM_WAREHOUSE_WITHDRAW uint16 = 0xC7

	// SM_WAREHOUSE_LIST carries the warehouse contents response. Payload (LE):
	//   int32 count
	//   for each row: int32 item_id, int32 item_count, int32 slot
	SM_WAREHOUSE_LIST uint16 = 0xC8

	// Auction house opcodes — Phase S-16.
	// NOTE: opcodes and payload formats unverified; adjust after packet capture.

	// CM_AUCTION_SEARCH requests the auction list filtered by optional params.
	// Payload (LE): int32 item_id_filter (0 = any), int64 min_price,
	//   int64 max_price, int32 page.
	CM_AUCTION_SEARCH uint16 = 0xC9

	// CM_AUCTION_REGISTER lists an item for sale.
	// Payload (LE): int32 item_id, int32 count, int64 min_bid, int64 buy_now,
	//   int32 duration_hours.
	CM_AUCTION_REGISTER uint16 = 0xCA

	// CM_AUCTION_BID places a bid on a listing.
	// Payload (LE): int64 listing_id, int64 bid_amount.
	CM_AUCTION_BID uint16 = 0xCB

	// CM_AUCTION_CANCEL withdraws a listing the caller owns.
	// Payload (LE): int64 listing_id.
	CM_AUCTION_CANCEL uint16 = 0xCC

	// SM_AUCTION_SEARCH_RESULT carries search response rows. Payload (LE):
	//   int32 count
	//   for each listing: int64 listing_id, int32 item_id, int32 item_count,
	//     int64 min_bid, int64 current_bid, int64 buy_now,
	//     int64 expires_at_unix, utf16_null seller_name
	SM_AUCTION_SEARCH_RESULT uint16 = 0xCD

	// SM_AUCTION_NOTIFY broadcasts a listing state change to the seller
	// and/or winner. Payload (LE):
	//   int64 listing_id, byte event (0=registered, 1=outbid, 2=sold,
	//     3=expired_unsold, 4=cancelled), int64 amount.
	SM_AUCTION_NOTIFY uint16 = 0xCE

	// Instance / dungeon opcodes — Phase S-19.
	// NOTE: opcodes and payload formats are best-effort; adjust after packet
	// capture against the 5.8 client.

	// CM_INSTANCE_ENTER is sent by the party leader (or a solo player with a
	// 1-member party) to enter an instanced dungeon. The server checks group
	// eligibility + per-member cooldowns via aion_getuserinstance_20171122,
	// then spawns a fresh run and teleports every member to the spawn point.
	// Payload (LE): int32 template_id.
	CM_INSTANCE_ENTER uint16 = 0xCF

	// SM_INSTANCE_ENTER_RESULT acknowledges a CM_INSTANCE_ENTER request.
	// Payload (LE):
	//   byte result (0=OK, 1=cooldown, 2=bad_level, 3=bad_group_size,
	//     4=not_leader, 5=already_in_instance, 6=db_error, 7=template_unknown),
	//   int64 run_id (0 on error),
	//   int32 cooldown_remaining_sec (>0 if result=1).
	SM_INSTANCE_ENTER_RESULT uint16 = 0xD0

	// CM_INSTANCE_LEAVE is sent when the player voluntarily exits the current
	// instance. The server teleports the caller back to their bind point but
	// leaves the run alive so party members can continue.
	// Payload: empty.
	CM_INSTANCE_LEAVE uint16 = 0xD1

	// SM_INSTANCE_STATE broadcasts an instance state transition
	// (LOBBY/ACTIVE/CLEARED/EXPIRED) to all members of the run.
	// Payload (LE): int64 run_id, byte state.
	SM_INSTANCE_STATE uint16 = 0xD2

	// SM_INSTANCE_REWARD notifies a member of rewards granted at boss clear.
	// Payload (LE):
	//   int64 run_id, int64 kinah,
	//   int32 item_count, then for each item: int32 id, int32 count.
	SM_INSTANCE_REWARD uint16 = 0xD3

	// CM_INSTANCE_RESET clears the caller's cooldown on a template in exchange
	// for a kinah fee. The player must not currently be inside that run.
	// Payload (LE): int32 template_id.
	CM_INSTANCE_RESET uint16 = 0xD4

	// SM_INSTANCE_COOLDOWNS carries the full list of the player's active
	// instance cooldowns (sent after login, reset, or explicit refresh).
	// Payload (LE):
	//   int32 count, then for each entry: int32 template_id,
	//     int32 next_allowed_at_unix.
	SM_INSTANCE_COOLDOWNS uint16 = 0xD5

	// SM_INSTANCE_MEMBER_JOIN notifies existing members that a new participant
	// entered (or rejoined) the run. Carries the entering entity's display name
	// so the party UI can render the roster without a follow-up query.
	// Payload (LE): int64 run_id, int32 member_eid, utf16_null name.
	SM_INSTANCE_MEMBER_JOIN uint16 = 0xD6

	// SM_INSTANCE_MEMBER_LEAVE notifies remaining members that a participant
	// exited the run (voluntary leave, disconnect, group-kick, or expire).
	// Payload (LE): int64 run_id, int32 member_eid.
	SM_INSTANCE_MEMBER_LEAVE uint16 = 0xD7
)

// LoginFailReason enumerates SM_LOGIN_FAIL reason codes.
type LoginFailReason uint8

const (
	LoginFailInvalidCredentials LoginFailReason = 0x03
	LoginFailAlreadyOnline      LoginFailReason = 0x0C
	LoginFailSystemError        LoginFailReason = 0x0F
	LoginFailBanned             LoginFailReason = 0x0D
)
