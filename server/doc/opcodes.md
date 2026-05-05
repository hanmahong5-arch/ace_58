# AION 5.8 Protocol Opcode Reference

Source: `server/src/internal/aionproto/opcodes.go`
Handlers: `server/scripts/handlers/cm_*.lua` (Lua) + `server/src/cmd/gateway/` (Go).

Total opcodes: **CM = 43, SM = 42** (85 total).

All integers are little-endian. Game packets use `uint16` opcodes; auth packets use `uint8`.
Payload is BF-LE encrypted from byte 2; XOR stream cipher is applied on top for client→server.

---

## By Phase

### Phase S-0: Auth Port Login (:2108, 0x00–0x07)

| Hex  | Name           | Dir | Handler / Sender                         | Notes |
|------|----------------|-----|------------------------------------------|-------|
| 0x00 | SM_KEY         | S→C | `cmd/gateway/handshake.go`               | First packet, unencrypted; RSA modulus + static BF key. |
| 0x01 | CM_AUTH_LOGIN  | C→S | `cmd/gateway/handshake.go`               | RSA-encrypted credentials. Go-handled, no Lua. |
| 0x02 | SM_LOGIN_OK    | S→C | `cmd/gateway/handshake.go`               | Server list payload. |
| 0x03 | SM_LOGIN_FAIL  | S→C | `cmd/gateway/handshake.go`               | Reason codes: 0x03/0x0C/0x0D/0x0F. |
| 0x05 | CM_PLAY        | C→S | `cmd/gateway/handshake.go`               | Server selection. Go-handled. |
| 0x06 | SM_PLAY_OK     | S→C | `cmd/gateway/handshake.go`               | Session token for game entry. |
| 0x07 | SM_PLAY_FAIL   | S→C | `cmd/gateway/handshake.go`               | |

### Phase S-1: Game Port Handshake (:7777, 0x0B–0x1B)

| Hex  | Name                 | Dir | Handler / Sender              | Notes |
|------|----------------------|-----|-------------------------------|-------|
| 0x0B | CM_VERSION_CHECK     | C→S | `cmd/gateway/game.go`         | First game-port packet. Go-handled. |
| 0x0C | SM_VERSION_CHECK_OK  | S→C | `cmd/gateway/game.go`         | Version accepted. |
| 0x1A | SM_SESSION_KEY       | S→C | `cmd/gateway/session.go`      | Per-session BF key. |
| 0x1B | CM_SESSION_CONFIRM   | C→S | `cmd/gateway/session.go`      | Carries token from auth server. Go-handled. |

### Phase S-2: Character Management (0x10–0x16)

| Hex  | Name                          | Dir | Handler / Sender              | Notes |
|------|-------------------------------|-----|-------------------------------|-------|
| 0x10 | SM_CHARACTER_LIST             | S→C | `scripts/handlers/cm_character_list.lua` (response) | Roster + metadata. |
| 0x11 | CM_CHARACTER_LIST             | C→S | `scripts/handlers/cm_character_list.lua` | |
| 0x12 | CM_CREATE_CHARACTER           | C→S | `scripts/handlers/cm_create_character.lua` | Phase F1 — replies with SM_CREATE_CHARACTER_RESPONSE 0x13. |
| 0x13 | SM_CREATE_CHARACTER_RESPONSE  | S→C | `scripts/handlers/cm_create_character.lua` (response) | Creation result. |
| 0x14 | CM_DELETE_CHARACTER           | C→S | `scripts/handlers/cm_delete_character.lua` | Phase F1 — soft-delete, replies with SM_DELETE_CHARACTER_RESPONSE 0x17. |
| 0x15 | CM_ENTER_WORLD                | C→S | `scripts/handlers/cm_enter_world.lua` | |
| 0x16 | SM_ENTER_WORLD_RESPONSE       | S→C | `scripts/handlers/cm_enter_world.lua` (response) | Initial world state. |
| 0x17 | SM_DELETE_CHARACTER_RESPONSE  | S→C | (sender TBD)                  | Phase S-18b: 7-day soft-delete grace window result. |

### Phase S-3: Movement, Combat, Core Play (0x0A, 0x0E, 0x19–0x9D, 0xAB)

| Hex  | Name              | Dir | Handler / Sender                  | Notes |
|------|-------------------|-----|-----------------------------------|-------|
| 0x0A | CM_MOVE           | C→S | `scripts/handlers/cm_move.lua`    | |
| 0x0E | CM_USE_SKILL      | C→S | `scripts/handlers/cm_use_skill.lua` | |
| 0x19 | SM_EXP_UPDATE     | S→C | `scripts/lib/skill.lua` / combat  | Wire format unverified. |
| 0x1E | SM_STAT_INFO      | S→C | `scripts/lib/skill.lua`, entry    | Player stats update. |
| 0x2C | CM_ATTACK         | C→S | `scripts/handlers/cm_attack.lua`  | Melee request. |
| 0x34 | SM_PLAYER_INFO    | S→C | enter-world + broadcast           | Detailed player info. |
| 0x3C | SM_BUFF_INFO      | S→C | `scripts/lib/buff.lua`            | Wire format unverified. |
| 0x41 | CM_EMOTION        | C→S | —                                 | ⚠ unhandled — client can send emote, server drops. |
| 0x44 | SM_DIE            | S→C | combat death path                 | Entity death broadcast. |
| 0x46 | CM_CHAT           | C→S | `scripts/handlers/cm_chat.lua`    | |
| 0x48 | SM_CHAT           | S→C | `scripts/lib/chat.lua`            | Chat broadcast. |
| 0x4C | SM_MOVE           | S→C | ECS movement broadcast            | Nearby observer sync. |
| 0x54 | SM_INVENTORY_INFO | S→C | enter-world + inventory change    | Initial inventory dump. |
| 0x55 | SM_LOOT_AVAILABLE | S→C | combat death loot path            | Round 11 — corpse drop-bag advert (entity_id + item_count). |
| 0x56 | CM_REVIVE_REQUEST | C→S | `scripts/handlers/cm_revive.lua`  | File named `cm_revive.lua`. |
| 0x57 | CM_LOOT_ITEM      | C→S | `scripts/handlers/cm_loot_item.lua` | Round 11 — pull item N from a corpse bag. |
| 0x58 | SM_LOOT_ITEMLIST  | S→C | loot pipeline                     | Round 11 — granted item + entropy block (forge_id + 6 stones + random_attrs). |
| 0x5E | SM_SKILL_RESULT   | S→C | `scripts/lib/skill.lua`           | Cast result broadcast. |
| 0x7A | SM_REVIVE         | S→C | `scripts/handlers/cm_revive.lua` (response) | |
| 0x8E | SM_ATTACK         | S→C | combat pipeline                   | Attack result broadcast. |
| 0x90 | SM_SKILL_FAILED   | S→C | `scripts/lib/skill.lua`           | Opcode unverified. |
| 0x9D | SM_LEVEL_UP       | S→C | exp / level system                | Wire format unverified. |
| 0xAB | CM_LOGOUT         | C→S | `scripts/handlers/cm_logout.lua`  | |

### Phase S-5: Party / Group (0x60–0x64)

| Hex  | Name                   | Dir | Handler / Sender                  | Notes |
|------|------------------------|-----|-----------------------------------|-------|
| 0x60 | CM_GROUP_INVITE        | C→S | `scripts/handlers/cm_group_invite.lua` | |
| 0x61 | CM_GROUP_ACCEPT        | C→S | `scripts/handlers/cm_group_accept.lua` | |
| 0x62 | CM_GROUP_LEAVE         | C→S | `scripts/handlers/cm_group_leave.lua`  | |
| 0x63 | SM_GROUP_INFO          | S→C | `scripts/lib/group.lua`                | Roster dump. |
| 0x64 | SM_GROUP_MEMBER_UPDATE | S→C | `scripts/lib/group.lua`                | On-tick HP/MP/level sync. |

### Phase S-6: Dialog & Shop (0x6A–0x70)

| Hex  | Name              | Dir | Handler / Sender                      | Notes |
|------|-------------------|-----|---------------------------------------|-------|
| 0x6A | CM_DIALOG_REQUEST | C→S | `scripts/handlers/cm_dialog_request.lua` | NPC right-click. |
| 0x6B | CM_DIALOG_SELECT  | C→S | `scripts/handlers/cm_dialog_select.lua`  | |
| 0x6C | CM_BUY_ITEM       | C→S | `scripts/handlers/cm_buy_item.lua`       | |
| 0x6D | CM_SELL_ITEM      | C→S | `scripts/handlers/cm_sell_item.lua`      | |
| 0x6E | CM_TELEPORT       | C→S | `scripts/handlers/cm_teleport.lua`       | Gatekeeper. |
| 0x6F | SM_DIALOG_WINDOW  | S→C | `scripts/lib/dialog.lua`                 | Dialog UI payload. |
| 0x70 | SM_TELEPORT_LOC   | S→C | teleport system                          | Relocation broadcast. |

### Phase S-7: Flight (0x71–0x76)

| Hex  | Name                   | Dir | Handler / Sender                        | Notes |
|------|------------------------|-----|-----------------------------------------|-------|
| 0x71 | CM_FLIGHT_TOGGLE       | C→S | `scripts/handlers/cm_flight_toggle.lua` | |
| 0x72 | CM_GLIDE_START         | C→S | `scripts/handlers/cm_glide_start.lua`   | |
| 0x73 | CM_GLIDE_END           | C→S | `scripts/handlers/cm_glide_end.lua`     | |
| 0x74 | SM_FLY_STATE           | S→C | `scripts/lib/flight.lua`                | Flight state broadcast. |
| 0x75 | CM_FLIGHT_PATH_SELECT  | C→S | `scripts/handlers/cm_flight_path_select.lua` | Flight Master. |
| 0x76 | SM_FLIGHT_PATH_START   | S→C | `scripts/lib/flight.lua`                | Scripted flight cinematic. |

### Phase S-10: Legion / Guild (0xB0–0xB7)

| Hex  | Name                     | Dir | Handler / Sender                      | Notes |
|------|--------------------------|-----|---------------------------------------|-------|
| 0xB0 | CM_LEGION_CREATE         | C→S | `scripts/handlers/cm_legion_create.lua` | 100k kinah fee. |
| 0xB1 | CM_LEGION_INVITE         | C→S | `scripts/handlers/cm_legion_invite.lua` | |
| 0xB2 | CM_LEGION_ACCEPT         | C→S | `scripts/handlers/cm_legion_accept.lua` | |
| 0xB3 | CM_LEGION_LEAVE          | C→S | `scripts/handlers/cm_legion_leave.lua`  | |
| 0xB4 | CM_LEGION_KICK           | C→S | `scripts/handlers/cm_legion_kick.lua`   | BG only. |
| 0xB5 | CM_LEGION_MOTD           | C→S | `scripts/handlers/cm_legion_motd.lua`   | Max 256 UTF-16 units. |
| 0xB6 | SM_LEGION_INFO           | S→C | `scripts/lib/legion.lua`                | Full roster. |
| 0xB7 | SM_LEGION_MEMBER_UPDATE  | S→C | `scripts/lib/legion.lua`                | Rank / online change. |

### Phase S-11: PvP / Abyss (0xB8–0xBA)

| Hex  | Name                  | Dir | Handler / Sender                      | Notes |
|------|-----------------------|-----|---------------------------------------|-------|
| 0xB8 | CM_PVP_FLAG_TOGGLE    | C→S | `scripts/handlers/cm_pvp_flag.lua`    | |
| 0xB9 | SM_PVP_FLAG           | S→C | `scripts/lib/pvp.lua`                 | Nameplate color update. |
| 0xBA | SM_ABYSS_POINT_UPDATE | S→C | `scripts/lib/pvp.lua`                 | AP delta notification. |

### Phase S-12: Equipment (0xBB–0xBD)

| Hex  | Name                 | Dir | Handler / Sender                        | Notes |
|------|----------------------|-----|-----------------------------------------|-------|
| 0xBB | CM_EQUIP_ITEM        | C→S | `scripts/handlers/cm_equip_item.lua`    | |
| 0xBC | CM_UNEQUIP_ITEM      | C→S | `scripts/handlers/cm_unequip_item.lua`  | |
| 0xBD | SM_EQUIPMENT_CHANGED | S→C | `scripts/lib/equipment.lua`             | Nearby-observer render sync. |

### Phase S-14: Mail (0xBE–0xC4)

| Hex  | Name           | Dir | Handler / Sender                      | Notes |
|------|----------------|-----|---------------------------------------|-------|
| 0xBE | CM_MAIL_SEND   | C→S | `scripts/handlers/cm_mail_send.lua`   | Attachable item + kinah. |
| 0xBF | CM_MAIL_LIST   | C→S | `scripts/handlers/cm_mail_list.lua`   | |
| 0xC0 | CM_MAIL_READ   | C→S | `scripts/handlers/cm_mail_read.lua`   | |
| 0xC1 | CM_MAIL_CLAIM  | C→S | `scripts/handlers/cm_mail_claim.lua`  | |
| 0xC2 | CM_MAIL_DELETE | C→S | `scripts/handlers/cm_mail_delete.lua` | |
| 0xC3 | SM_MAIL_LIST   | S→C | `scripts/lib/mail.lua`                | Inbox response. |
| 0xC4 | SM_MAIL_NEW    | S→C | `scripts/lib/mail.lua`                | New mail notification. |

### Phase S-15: Warehouse (0xC5–0xC8)

| Hex  | Name                  | Dir | Handler / Sender                           | Notes |
|------|-----------------------|-----|--------------------------------------------|-------|
| 0xC5 | CM_WAREHOUSE_LIST     | C→S | `scripts/handlers/cm_warehouse_list.lua`   | |
| 0xC6 | CM_WAREHOUSE_DEPOSIT  | C→S | `scripts/handlers/cm_warehouse_deposit.lua`| |
| 0xC7 | CM_WAREHOUSE_WITHDRAW | C→S | `scripts/handlers/cm_warehouse_withdraw.lua`| |
| 0xC8 | SM_WAREHOUSE_LIST     | S→C | `scripts/lib/warehouse.lua`                | Contents response. |

### Phase S-16: Auction House (0xC9–0xCE)

| Hex  | Name                     | Dir | Handler / Sender                          | Notes |
|------|--------------------------|-----|-------------------------------------------|-------|
| 0xC9 | CM_AUCTION_SEARCH        | C→S | `scripts/handlers/cm_auction_search.lua`  | |
| 0xCA | CM_AUCTION_REGISTER      | C→S | `scripts/handlers/cm_auction_register.lua`| |
| 0xCB | CM_AUCTION_BID           | C→S | `scripts/handlers/cm_auction_bid.lua`     | |
| 0xCC | CM_AUCTION_CANCEL        | C→S | `scripts/handlers/cm_auction_cancel.lua`  | |
| 0xCD | SM_AUCTION_SEARCH_RESULT | S→C | `scripts/lib/auction.lua`                 | Search rows. |
| 0xCE | SM_AUCTION_NOTIFY        | S→C | `scripts/lib/auction.lua`                 | Listing state change. |

### Phase S-19: Instance / Dungeon (0xCF–0xD7)

| Hex  | Name                      | Dir | Handler / Sender                           | Notes |
|------|---------------------------|-----|--------------------------------------------|-------|
| 0xCF | CM_INSTANCE_ENTER         | C→S | `scripts/handlers/cm_instance_enter.lua`   | Party leader (or solo) requests entry; payload int32 template_id. |
| 0xD0 | SM_INSTANCE_ENTER_RESULT  | S→C | `scripts/handlers/cm_instance_enter.lua`   | byte result + int64 run_id + int32 cooldown_remaining. |
| 0xD1 | CM_INSTANCE_LEAVE         | C→S | `scripts/handlers/cm_instance_leave.lua`   | Caller exits the run; bind-point teleport. |
| 0xD2 | SM_INSTANCE_STATE         | S→C | `scripts/lib/instance.lua`                 | State transition (LOBBY/ACTIVE/CLEARED/EXPIRED). |
| 0xD3 | SM_INSTANCE_REWARD        | S→C | `scripts/lib/instance.lua`                 | Boss-clear payout (kinah + items). |
| 0xD4 | CM_INSTANCE_RESET         | C→S | `scripts/handlers/cm_instance_reset.lua`   | Pay kinah to clear a template's cooldown. |
| 0xD5 | SM_INSTANCE_COOLDOWNS     | S→C | `scripts/lib/instance.lua`                 | Full cooldown list (on login / post-reset). |
| 0xD6 | SM_INSTANCE_MEMBER_JOIN   | S→C | `scripts/lib/instance.lua`                 | New participant joined the run. |
| 0xD7 | SM_INSTANCE_MEMBER_LEAVE  | S→C | `scripts/lib/instance.lua`                 | Participant exited (leave / kick / expire). |

Reserved: 0xD8 (future boss-phase state broadcast).

---

## Alphabetical Index (CM_)

| Name                    | Hex  | Phase | Handler |
|-------------------------|------|-------|---------|
| CM_ATTACK               | 0x2C | S-3   | cm_attack.lua |
| CM_AUCTION_BID          | 0xCB | S-16  | cm_auction_bid.lua |
| CM_AUCTION_CANCEL       | 0xCC | S-16  | cm_auction_cancel.lua |
| CM_AUCTION_REGISTER     | 0xCA | S-16  | cm_auction_register.lua |
| CM_AUCTION_SEARCH       | 0xC9 | S-16  | cm_auction_search.lua |
| CM_AUTH_LOGIN           | 0x01 | S-0   | Go: handshake.go |
| CM_BUY_ITEM             | 0x6C | S-6   | cm_buy_item.lua |
| CM_CHARACTER_LIST       | 0x11 | S-2   | cm_character_list.lua |
| CM_CHAT                 | 0x46 | S-3   | cm_chat.lua |
| CM_CREATE_CHARACTER     | 0x12 | S-2   | cm_create_character.lua |
| CM_DELETE_CHARACTER     | 0x14 | S-2   | cm_delete_character.lua |
| CM_DIALOG_REQUEST       | 0x6A | S-6   | cm_dialog_request.lua |
| CM_DIALOG_SELECT        | 0x6B | S-6   | cm_dialog_select.lua |
| CM_EMOTION              | 0x41 | S-3   | ⚠ unhandled |
| CM_ENTER_WORLD          | 0x15 | S-2   | cm_enter_world.lua |
| CM_EQUIP_ITEM           | 0xBB | S-12  | cm_equip_item.lua |
| CM_INSTANCE_ENTER       | 0xCF | S-19  | cm_instance_enter.lua |
| CM_INSTANCE_LEAVE       | 0xD1 | S-19  | cm_instance_leave.lua |
| CM_INSTANCE_RESET       | 0xD4 | S-19  | cm_instance_reset.lua |
| CM_FLIGHT_PATH_SELECT   | 0x75 | S-7   | cm_flight_path_select.lua |
| CM_FLIGHT_TOGGLE        | 0x71 | S-7   | cm_flight_toggle.lua |
| CM_GLIDE_END            | 0x73 | S-7   | cm_glide_end.lua |
| CM_GLIDE_START          | 0x72 | S-7   | cm_glide_start.lua |
| CM_GROUP_ACCEPT         | 0x61 | S-5   | cm_group_accept.lua |
| CM_GROUP_INVITE         | 0x60 | S-5   | cm_group_invite.lua |
| CM_GROUP_LEAVE          | 0x62 | S-5   | cm_group_leave.lua |
| CM_LEGION_ACCEPT        | 0xB2 | S-10  | cm_legion_accept.lua |
| CM_LOOT_ITEM            | 0x57 | R11   | cm_loot_item.lua |
| CM_LEGION_CREATE        | 0xB0 | S-10  | cm_legion_create.lua |
| CM_LEGION_INVITE        | 0xB1 | S-10  | cm_legion_invite.lua |
| CM_LEGION_KICK          | 0xB4 | S-10  | cm_legion_kick.lua |
| CM_LEGION_LEAVE         | 0xB3 | S-10  | cm_legion_leave.lua |
| CM_LEGION_MOTD          | 0xB5 | S-10  | cm_legion_motd.lua |
| CM_LOGOUT               | 0xAB | S-3   | cm_logout.lua |
| CM_MAIL_CLAIM           | 0xC1 | S-14  | cm_mail_claim.lua |
| CM_MAIL_DELETE          | 0xC2 | S-14  | cm_mail_delete.lua |
| CM_MAIL_LIST            | 0xBF | S-14  | cm_mail_list.lua |
| CM_MAIL_READ            | 0xC0 | S-14  | cm_mail_read.lua |
| CM_MAIL_SEND            | 0xBE | S-14  | cm_mail_send.lua |
| CM_MOVE                 | 0x0A | S-3   | cm_move.lua |
| CM_PLAY                 | 0x05 | S-0   | Go: handshake.go |
| CM_PVP_FLAG_TOGGLE      | 0xB8 | S-11  | cm_pvp_flag.lua |
| CM_REVIVE_REQUEST       | 0x56 | S-3   | cm_revive.lua |
| CM_SELL_ITEM            | 0x6D | S-6   | cm_sell_item.lua |
| CM_SESSION_CONFIRM      | 0x1B | S-1   | Go: session.go |
| CM_TELEPORT             | 0x6E | S-6   | cm_teleport.lua |
| CM_UNEQUIP_ITEM         | 0xBC | S-12  | cm_unequip_item.lua |
| CM_USE_SKILL            | 0x0E | S-3   | cm_use_skill.lua |
| CM_VERSION_CHECK        | 0x0B | S-1   | Go: game.go |
| CM_WAREHOUSE_DEPOSIT    | 0xC6 | S-15  | cm_warehouse_deposit.lua |
| CM_WAREHOUSE_LIST       | 0xC5 | S-15  | cm_warehouse_list.lua |
| CM_WAREHOUSE_WITHDRAW   | 0xC7 | S-15  | cm_warehouse_withdraw.lua |

## Alphabetical Index (SM_)

| Name                          | Hex  | Phase | Sent from |
|-------------------------------|------|-------|-----------|
| SM_ABYSS_POINT_UPDATE         | 0xBA | S-11  | scripts/lib/pvp.lua |
| SM_ATTACK                     | 0x8E | S-3   | combat pipeline |
| SM_AUCTION_NOTIFY             | 0xCE | S-16  | scripts/lib/auction.lua |
| SM_AUCTION_SEARCH_RESULT      | 0xCD | S-16  | scripts/lib/auction.lua |
| SM_BUFF_INFO                  | 0x3C | S-3   | scripts/lib/buff.lua |
| SM_CHARACTER_LIST             | 0x10 | S-2   | cm_character_list.lua |
| SM_CHAT                       | 0x48 | S-3   | scripts/lib/chat.lua |
| SM_CREATE_CHARACTER_RESPONSE  | 0x13 | S-2   | (sender TBD) |
| SM_DELETE_CHARACTER_RESPONSE  | 0x17 | S-18b | (sender TBD) |
| SM_DIALOG_WINDOW              | 0x6F | S-6   | scripts/lib/dialog.lua |
| SM_DIE                        | 0x44 | S-3   | combat death |
| SM_ENTER_WORLD_RESPONSE       | 0x16 | S-2   | cm_enter_world.lua |
| SM_EQUIPMENT_CHANGED          | 0xBD | S-12  | scripts/lib/equipment.lua |
| SM_EXP_UPDATE                 | 0x19 | S-3   | scripts/lib/skill.lua |
| SM_FLIGHT_PATH_START          | 0x76 | S-7   | scripts/lib/flight.lua |
| SM_FLY_STATE                  | 0x74 | S-7   | scripts/lib/flight.lua |
| SM_GROUP_INFO                 | 0x63 | S-5   | scripts/lib/group.lua |
| SM_GROUP_MEMBER_UPDATE        | 0x64 | S-5   | scripts/lib/group.lua |
| SM_INSTANCE_COOLDOWNS         | 0xD5 | S-19  | scripts/lib/instance.lua |
| SM_INSTANCE_ENTER_RESULT      | 0xD0 | S-19  | cm_instance_enter.lua |
| SM_INSTANCE_MEMBER_JOIN       | 0xD6 | S-19  | scripts/lib/instance.lua |
| SM_INSTANCE_MEMBER_LEAVE      | 0xD7 | S-19  | scripts/lib/instance.lua |
| SM_INSTANCE_REWARD            | 0xD3 | S-19  | scripts/lib/instance.lua |
| SM_INSTANCE_STATE             | 0xD2 | S-19  | scripts/lib/instance.lua |
| SM_INVENTORY_INFO             | 0x54 | S-3   | enter-world + inventory change |
| SM_KEY                        | 0x00 | S-0   | cmd/gateway/handshake.go |
| SM_LEGION_INFO                | 0xB6 | S-10  | scripts/lib/legion.lua |
| SM_LEGION_MEMBER_UPDATE       | 0xB7 | S-10  | scripts/lib/legion.lua |
| SM_LEVEL_UP                   | 0x9D | S-3   | exp / level system |
| SM_LOOT_AVAILABLE             | 0x55 | R11   | combat death loot path |
| SM_LOOT_ITEMLIST              | 0x58 | R11   | loot pipeline |
| SM_LOGIN_FAIL                 | 0x03 | S-0   | cmd/gateway/handshake.go |
| SM_LOGIN_OK                   | 0x02 | S-0   | cmd/gateway/handshake.go |
| SM_MAIL_LIST                  | 0xC3 | S-14  | scripts/lib/mail.lua |
| SM_MAIL_NEW                   | 0xC4 | S-14  | scripts/lib/mail.lua |
| SM_MOVE                       | 0x4C | S-3   | ECS movement broadcast |
| SM_PLAY_FAIL                  | 0x07 | S-0   | cmd/gateway/handshake.go |
| SM_PLAY_OK                    | 0x06 | S-0   | cmd/gateway/handshake.go |
| SM_PLAYER_INFO                | 0x34 | S-3   | enter-world + broadcast |
| SM_PVP_FLAG                   | 0xB9 | S-11  | scripts/lib/pvp.lua |
| SM_REVIVE                     | 0x7A | S-3   | cm_revive.lua |
| SM_SESSION_KEY                | 0x1A | S-1   | cmd/gateway/session.go |
| SM_SKILL_FAILED               | 0x90 | S-3   | scripts/lib/skill.lua |
| SM_SKILL_RESULT               | 0x5E | S-3   | scripts/lib/skill.lua |
| SM_STAT_INFO                  | 0x1E | S-3   | scripts/lib/skill.lua + entry |
| SM_TELEPORT_LOC               | 0x70 | S-6   | teleport system |
| SM_VERSION_CHECK_OK           | 0x0C | S-1   | cmd/gateway/game.go |
| SM_WAREHOUSE_LIST             | 0xC8 | S-15  | scripts/lib/warehouse.lua |

---

## Unused / Reserved Ranges

Available opcode slots (suitable for future phases S-20+):

| Range        | Size | Suggested Use |
|--------------|------|---------------|
| 0x04         | 1    | Auth-port expansion |
| 0x08–0x09    | 2    | Handshake expansion (0x0A/0x0B/0x0C/0x0E already used) |
| 0x0D, 0x0F   | 2    | — |
| 0x18         | 1    | Character management expansion (0x17 = SM_DELETE_CHARACTER_RESPONSE) |
| 0x1C–0x1D    | 2    | Session expansion |
| 0x1F–0x2B    | 13   | Large free block |
| 0x2D–0x33    | 7    | Combat expansion |
| 0x35–0x3B    | 7    | Player info expansion |
| 0x3D–0x40    | 4    | Buff expansion |
| 0x42–0x43    | 2    | — |
| 0x45, 0x47   | 2    | Chat expansion |
| 0x49–0x4B    | 3    | — |
| 0x4D–0x53    | 7    | Movement expansion |
| 0x59–0x5D    | 5    | Skill expansion (0x55/0x57/0x58 used by Round 11 loot) |
| 0x5F, 0x65–0x69 | 6 | Group / pre-dialog expansion |
| 0x77–0x79    | 3    | Flight overflow |
| 0x7B–0x8D    | 19   | Large free block — recommended for S-17 combat/PvE |
| 0x8F, 0x91–0x9C | 13 | Skill expansion |
| 0x9E–0xAA    | 13   | Free block |
| 0xAC–0xAF    | 4    | Logout / system expansion |
| 0xD8         | 1    | Reserved for instance boss-phase state (S-19 reserved) |
| 0xD9–0xFF    | 39   | **Large free block for S-20+** — recommended for pets, housing, BGs, P2P trade |

Grand total reserved: ~161 free slots before hitting opcode exhaustion at 0x100.

---

## Collision Detection

Automated scan of the 85 constants against duplicate hex values: **zero collisions**. Each opcode maps to exactly one name.

Verification method: sort all `uint16` literals in `opcodes.go`, compare adjacent values. Closest neighbors (0x0A→0x0B, 0x62→0x63, 0xBB→0xBC, etc.) are distinct by design — no overlap within ±0.

---

## Unhandled CM_ Opcodes (Genuine Gaps)

The following CM_ opcodes are defined in `opcodes.go` but have **neither a Go handler nor a Lua handler file**. The client can transmit them; the server silently drops the packet.

| Hex  | Name                 | Impact |
|------|----------------------|--------|
| 0x41 | CM_EMOTION           | Emotes do not broadcast. Cosmetic only. |

Action: register a Lua handler in `scripts/handlers/cm_emotion.lua` in the next phase.

Resolved gaps (kept here for traceability):
- 0x12 `CM_CREATE_CHARACTER` — handled by `scripts/handlers/cm_create_character.lua` (Phase F1).
- 0x14 `CM_DELETE_CHARACTER` — handled by `scripts/handlers/cm_delete_character.lua` (Phase F1).

---

*Last verified against `src/internal/aionproto/opcodes.go` and `scripts/handlers/` on **2026-05-05**.*
