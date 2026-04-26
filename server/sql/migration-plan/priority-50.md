# Sprint 1.1a — Priority 50 NCSoft SP Port List

**Round 4 Track B2 deliverable.** Goal: identify the 50 most critical NCSoft
T-SQL stored procedures to port to PostgreSQL plpgsql for the **single-player
PvE loop** (login → char-select → enter world → kill mobs → loot → exp → save
→ logout). Auction, full PvP, group, and housing flows are deferred to Round
5+.

## Selection Method

1. Audit `scripts/**/*.lua` for every `db.call("...")` (37 unique SP names,
   49 call sites — see Round 4 report).
2. Match against the 1059 NCSoft AionWorldLive SPs in
   `ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/` (17 matched, 20 use
   names invented by Lua devs that don't appear in NCSoft).
3. Augment with NCSoft SPs the Lua hasn't touched yet but that the dev-guide
   three-layer rule will require for the PvE loop (item insert, skill learn,
   quest progress, char location persistence).
4. Sort by criticality bucket (login → char → inventory → skill → quest →
   guild → instance → mail → world).

## Status Legend

- `PORTED` — landed in this round (00003-00007)
- `LUA-NEEDS` — Lua already calls this SP but no PG impl yet (Round 5 priority)
- `NCSOFT-ONLY` — exists in NCSoft dump, no Lua caller yet but PvE loop needs it
- `MISSING` — Lua wants it but the literal name doesn't exist in NCSoft (needs
  human decision: rename to NCSoft equivalent, or write a fresh PG-only SP)

## The 50

### Login & Character Lifecycle (10)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 1 | `aion_GetCharIdList` | NCSOFT-ONLY | Char-select screen needs the list of account's chars |
| 2 | `aion_GetCharBuilder` | NCSOFT-ONLY | Char-select preview (face/hair) without loading full char |
| 3 | `aion_GetCharInfo_20160818` | LUA-NEEDS | Master load on enter world (called from `cm_enter_world.lua`) |
| 4 | `aion_PutChar_20160620` | LUA-NEEDS | Character creation insert (`cm_create_character.lua`) |
| 5 | `aion_CheckValidCharName` | LUA-NEEDS | Name validation against `forbidden_word` table |
| 6 | `aion_SetCharDeleteTime` | **PORTED** | Schedule pending deletion — `00006_sp_set_char_delete_time.sql` |
| 7 | `aion_SetCharLoginTime_20120516` | NCSOFT-ONLY | Stamp last_login_time (req'd by daily-reset logic) |
| 8 | `aion_SetCharCP` | NCSOFT-ONLY | Champion-point currency (used during PvE rewards) |
| 9 | `aion_AddCharRankPoint` | NCSOFT-ONLY | Rank-point grant on kill (PvE solo abyss) |
| 10 | `aion_GetCharGuildId` | **PORTED** | Lookup char's guild — `00003_sp_get_char_guild_id.sql` |

### Inventory (10)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 11 | `aion_GetItem` | NCSOFT-ONLY | Load all items for char on enter world |
| 12 | `aion_PutItem_20150921` | NCSOFT-ONLY | Insert new item (drop, quest reward, mail attach) |
| 13 | `aion_SetItemAmount` | NCSOFT-ONLY | Stack count update (consumables) |
| 14 | `aion_SetItemEnchant` | NCSOFT-ONLY | Enchant level update |
| 15 | `aion_GetItemByTid` | NCSOFT-ONLY | Lookup by item template id |
| 16 | `aion_PutItemBind` | NCSOFT-ONLY | Bind item on first equip |
| 17 | `aion_RemoveItemBind` | NCSOFT-ONLY | Unbind via item-shop service |
| 18 | `aion_PutItemCoolTime` | NCSOFT-ONLY | Item cooldown (potions) |
| 19 | `aion_SetItemDye_20111227` | NCSOFT-ONLY | Dye appearance |
| 20 | `aion_DeleteItem` | MISSING | Sell/destroy item — confirm exact NCSoft name |

### Skills (5)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 21 | `aion_GetSkillList` | NCSOFT-ONLY | Load known skills on enter world |
| 22 | `aion_PutSkill` | NCSOFT-ONLY | Learn skill on level-up |
| 23 | `aion_GetSkillCooltime` | NCSOFT-ONLY | Restore cooldown on enter world |
| 24 | `aion_PutSkillCooltime` | NCSOFT-ONLY | Persist cooldown for logout-safe combat |
| 25 | `aion_PutSkillSkin` | NCSOFT-ONLY | Cosmetic skin from item shop |

### Quests (2)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 26 | `aion_GetQuestList` | NCSOFT-ONLY | Load all quest states on enter world |
| 27 | `aion_PutQuest` | NCSOFT-ONLY | Create/update single quest progress |

### Legion / Guild (8)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 28 | `aion_PutGuild_20100916` | LUA-NEEDS | Create new legion |
| 29 | `aion_DeleteGuild` | **PORTED** | Disband — `00004_sp_delete_guild.sql` |
| 30 | `aion_DeleteGuildMemberAll` | LUA-NEEDS | Wipe roster on disband |
| 31 | `aion_GetGuild_20150508` | **PORTED** | Load legion data — `00005_sp_get_guild_20150508.sql` |
| 32 | `aion_SetGuildMember` | **PORTED** | Bind char to guild — `00007_sp_set_guild_member.sql` |
| 33 | `aion_SetGuildMemberRank` | LUA-NEEDS | Promote/demote rank |
| 34 | `aion_SetGuildNotices` | LUA-NEEDS | MOTD update (15 params, complex) |
| 35 | `aion_GetGuildMember` | MISSING | Roster fetch — confirm exact NCSoft name |

### Instance / Cooltime (3)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 36 | `aion_GetUserInstance_20171122` | LUA-NEEDS | Load instance entry on enter world (3 callers) |
| 37 | `aion_SetUserInstance_20171122` | LUA-NEEDS | Update entry/lock (3 callers) |
| 38 | `aion_InitInstanceCooltime_170817` | LUA-NEEDS | Daily-reset cleanup |

### Mail (7)

NCSoft uses `aion_Mail*` prefix; Lua scripts invented `aion_*Mail*` names. Use
NCSoft names in PG ports and update Lua wrappers in Round 5.

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 39 | `aion_MailWriteSys_20111227` | LUA-NEEDS | Send system mail (compensation, events) |
| 40 | `aion_MailList` | NCSOFT-ONLY | Inbox listing (Lua wants `aion_GetMailsByUser` — rename in caller) |
| 41 | `aion_MailRead` | NCSOFT-ONLY | Mark as read (Lua wants `aion_UpdateMailRead`) |
| 42 | `aion_MailDelete` | NCSOFT-ONLY | Delete one mail (Lua wants `aion_DeleteMail`) |
| 43 | `aion_MailGetItem` | NCSOFT-ONLY | Claim attachment (Lua wants `aion_ClaimMailAttachment`) |
| 44 | `aion_MailGetBoxSize` | NCSOFT-ONLY | Enforce inbox cap |
| 45 | `aion_MailCheckReceiver_20091007` | NCSOFT-ONLY | Validate recipient before send |

### World / Movement / Abyss (5)

| # | SP | Status | Rationale |
|---|----|--------|-----------|
| 46 | `aion_PutCharLogout` | MISSING | Stamp last_logout_time — confirm NCSoft name |
| 47 | `aion_PutCharLocation` | MISSING | Persist coords on logout — likely embedded in PutChar |
| 48 | `aion_GetCharLocation` | MISSING | Restore coords — likely embedded in GetCharInfo |
| 49 | `aion_GetAbyssGuildRank` | NCSOFT-ONLY | Legion abyss rank UI |
| 50 | `aion_GetAbyssRankingNew` | NCSOFT-ONLY | Top-N board for in-game UI |

## Summary

| Status | Count |
|--------|-------|
| **PORTED** (Round 4) | 5 |
| LUA-NEEDS (Round 5 must-have) | 11 |
| NCSOFT-ONLY (Round 5/6) | 30 |
| MISSING (need rename or new SP) | 4 |

## Round 5 Recommendation

Next 10-20 to port, in priority order:

1. `aion_GetCharInfo_20160818` — most critical Lua dependency, `cm_enter_world.lua` is blocked without it
2. `aion_PutChar_20160620` — char create blocked without it (large SP, ~7.5KB)
3. `aion_CheckValidCharName` — char create dependency
4. `aion_GetCharIdList` — char-select screen
5. `aion_PutGuild_20100916` — legion creation (Lua-demanded)
6. `aion_GetUserInstance_20171122` — instance entry (Lua-demanded x3)
7. `aion_SetUserInstance_20171122` — instance entry (Lua-demanded x3)
8. `aion_InitInstanceCooltime_170817` — daily reset (Lua-demanded)
9. `aion_DeleteGuildMemberAll` — legion disband (Lua-demanded)
10. `aion_SetGuildMemberRank` — legion rank (Lua-demanded x2)
11. `aion_SetGuildNotices` — legion MOTD (Lua-demanded, 15 params)
12. `aion_MailWriteSys_20111227` — system mail (Lua-demanded)
13. `aion_GetItem` — inventory load
14. `aion_PutItem_20150921` — inventory insert
15. `aion_GetSkillList` — skill load
16. `aion_PutSkill` — skill learn
17. `aion_GetQuestList` — quest load
18. `aion_PutQuest` — quest progress

This satisfies all 11 outstanding Lua-NEEDS plus opens up inventory/skill/
quest enough for the first end-to-end "kill mob → loot → exp → save" loop.

## Notes for Human Review

Four MISSING items need a decision before Round 5:

- `aion_PutCharLogout` / `aion_PutCharLocation` / `aion_GetCharLocation` —
  these likely don't exist as standalone SPs because NCSoft folded the logic
  into `aion_PutChar_20160620` (look for `last_logout_time` / `x` / `y` / `z`
  columns being set there). Confirm and either delete from this list or
  define new PG-only SPs.
- `aion_DeleteItem` — search NCSoft dump for `aion_RemoveItem*` /
  `aion_DelItem*` variants.
- `aion_GetGuildMember` — search for `aion_GetGuild*Member*` variants.

For the 20 Lua-invented names that don't exist in NCSoft (see Round 4
report — auction/mail/warehouse/abyss/bind family), Round 5 must:
  (a) rename Lua callers to use the actual NCSoft SP name, or
  (b) write a fresh PG-only SP that wraps the right NCSoft schema.

Auction SPs (`aion_GetAuctionById`, `aion_settleauction`, etc.) are listed
in NCSoft as `aion_addAuction`/`aion_GetAuctionBettingList`/etc. — the Lua
auction layer needs a full rewrite against the real NCSoft auction schema
or, given the high-entropy roadmap, the auction system can be left as a
Round 6+ feature (single-player PvE doesn't need it).

---

## Round 5 (Track B3) Outcome — 2026-04-25

### Resolution of the 4 MISSING SPs

| MISSING name | Resolution | Migration |
|---|---|---|
| `aion_PutCharLogout` | Found NCSoft equivalent: **`aion_SetCharLogoutTime_20120516`** — bumps `last_logout_time` + accumulates `playtime`. Round 4 audit just used a different naming convention. | `00011_sp_set_char_logout_time.sql` |
| `aion_PutCharLocation` | Found NCSoft equivalent: **`aion_SetCharLocation`** — same intent, different verb. | `00013_sp_set_char_location.sql` |
| `aion_GetCharLocation` | NCSoft truly has no standalone SP — coords are folded into the giant `aion_GetCharInfo_20160818`. Wrote a focused PG-only `aion_getcharlocation` that returns just the 6 coord cols. | `00014_sp_get_char_location.sql` |
| `aion_DeleteItem` | **Exists in NCSoft dump** as `aion_DeleteItem`. Round 4 audit missed it. Cascading DELETE across user_item + 4 sister tables. | `00019_sp_delete_item.sql` |
| `aion_GetGuildMember` | NCSoft has `GM_GuildDA_SrchGuildMembers` (paginated, GM-tool oriented). For runtime we'd want a simpler "list members" SP — **deferred to Round 6** since the legion roster UI isn't on the PvE-loop critical path. |  — |

### Resolution of the 20 unmatched (Lua-invented) names

| Group | Count | Decision |
|---|---|---|
| Auction (`aion_GetAuctionById`, `aion_settleauction`, etc.) | 8 | **Defer to Round 7** — no auction in Q1 single-player PvE. |
| Warehouse (`aion_PutCharWarehouseSlot`, etc.) | 3 | **Defer to Round 7** — not on critical path. |
| Mail (`aion_GetMailsByUser`, `aion_UpdateMailRead`, etc.) | 5 | **Rename Lua callers** in Round 6 to use NCSoft `aion_Mail*` family. Already ported `aion_MailWriteSys_20111227` (00031) — covers the system-mail / quest-reward delivery path. The 4 read-side mail SPs (`aion_MailList`, `aion_MailRead`, `aion_MailDelete`, `aion_MailGetItem`) deferred to Round 6. |
| Abyss (`aion_setabyssrankthisweek`) | 1 | **Defer to Round 7** — abyss PvP not Q1. |
| Other (`ap_update_skill_usage`, etc.) | 3 | Genuinely home-grown (the `ap_*` prefix gives it away — not NCSoft). **Defer to Round 6** — write fresh PG-only SPs once the runtime actually needs them. |

### 18 Priority SPs — Port Status

| # | SP | Status | Migration | Notes |
|---|----|--------|-----------|-------|
| 1 | `aion_GetCharInfo_20160818` | **TODO B4** | — | 120-col SELECT requires full PutChar scaffold (face, customize, etc.). Round 5 scaffold only adds the 17 cols required by the simpler SPs. Defer to B4 dedicated SP. |
| 2 | `aion_PutChar_20160620` | **TODO B4** | — | 110-col INSERT, 99 face/feature columns not in scaffold. Defer to B4 + write `00032_pve_scaffold_round3.sql` first. |
| 3 | `aion_CheckValidCharName` | **PORTED** | 00010 | Tested: returns 0 for fresh, -1 for taken. forbidden_word/forbidden_char tables in scaffold. |
| 4 | `aion_GetCharIdList` | **PORTED** | 00009 | Tested: filters delete_date correctly. |
| 5 | `aion_PutGuild_20100916` | **PORTED** | 00030 | Tested: returns new id, -1 on duplicate. |
| 6 | `aion_GetUserInstance_20171122` | **PORTED** | 00025 | Tested: incl. lobby DELETE side-effect + LEFT JOIN instance. (Hit + fixed `world_id` ambiguity bug — RETURNS TABLE OUT params now `out_*` prefixed.) |
| 7 | `aion_SetUserInstance_20171122` | **PORTED** | 00026 | Tested: upsert via INSERT...ON CONFLICT. |
| 8 | `aion_InitInstanceCooltime_170817` | **PORTED** | 00027 | Tested: sweeps stale rows >8h old. |
| 9 | `aion_DeleteGuildMemberAll` | **PORTED** | 00028 | Tested: wipes all members of a guild. |
| 10 | `aion_SetGuildMemberRank` | **PORTED** | 00029 | Tested: matched (char_id, guild_id) pair only. |
| 11 | `aion_SetGuildNotices` | **DEFERRED** | — | 15-param MOTD update, requires guild.notice1..7 columns not in scaffold. Round 6. |
| 12 | `aion_MailWriteSys_20111227` | **PORTED** | 00031 | Tested: insert + optional item attachment transfer. |
| 13 | `aion_GetItem` | **PORTED** | 00017 | Tested as part of inventory round-trip. |
| 14 | `aion_PutItem_20150921` | **PORTED** | 00018 | Tested: 41 params, conditional user_item_option insert when any flag non-default. |
| 15 | `aion_GetSkillList` | **PORTED** | 00021 | Tested as part of skill round-trip. |
| 16 | `aion_PutSkill` | **PORTED** | 00022 | Tested: upsert idempotence verified. |
| 17 | `aion_GetQuestList` | **PORTED** | 00023 | Tested as part of quest round-trip. |
| 18 | `aion_PutQuest` | **PORTED** | 00024 | Tested: ON CONFLICT DO NOTHING; SetQuest (Round 6) will handle updates. |

**Bonus ports** (supporting infrastructure for the e2e smoke):
- `aion_SetCharLogoutTime_20120516` (00011) — was MISSING #46
- `aion_SetCharLoginTime_20120516` (00012) — needed by SetCharLogoutTime (subtracts last_login_time)
- `aion_SetCharLocation` (00013) — was MISSING #47
- `aion_GetCharLocation` (00014, PG-only) — was MISSING #48
- `aion_SetCharCP` (00015) — PvE reward currency
- `aion_AddCharRankPoint` (00016) — Abyss rank grant on kill
- `aion_DeleteItem` (00019) — was MISSING #20
- `aion_SetItemAmount` (00020) — consumable stack update

### Counts after Round 5

| Status | Count |
|---|---|
| **PORTED** (Rounds 4 + 5) | 5 + 21 = **26** |
| TODO B4 (PutChar / GetCharInfo) | 2 |
| Deferred to Round 6+ | 22 |

### Test count delta

- Round 4 baseline: 313 passing
- Round 5: **341 passing**, 0 failing, 0 skipped (with `AION_TEST_PG_*` env)
- Delta: **+28** (15 Round 5 SP subtests + 1 e2e smoke + auto-detected luahost growth)
- Default path (no PG env): all DB tests skip cleanly, others green.

### Round 6 recommendation — next 15-20 SPs to unlock combat / skill / quest fully

**Priority A — finish PvE loop (must-have)**:
1. `aion_PutChar_20160620` — block on writing scaffold round 3 (99 face cols)
2. `aion_GetCharInfo_20160818` — same blocker
3. `aion_SetCharInfo_20160818` — periodic stat snapshot persist
4. `aion_GetCharBuilder` — char-select preview (subset of GetCharInfo)
5. `aion_SetQuest` (or version-suffixed variant) — quest progress UPDATE
6. `aion_DeleteQuest` — quest abandon
7. `aion_PutFinishedQuestSimple` — log completion for daily-reset gating
8. `aion_GetItemList_20120102` — bulk inventory load on enter-world
9. `aion_SetItemEnchant_20180615` — enchant stone outcome persist
10. `aion_SetItemAmount` already ported; add `aion_SetItemSlotId` + `aion_SetItemSlotNum` for inventory rearrange
11. `aion_GetSkillCooltime` + `aion_PutSkillCooltime` — combat-state safety on logout
12. `aion_PutSkillSkin` — cosmetic skin apply

**Priority B — guild UI & mail inbox**:
13. `aion_SetGuildNotices` — 15-param MOTD (needs guild.notice1..7 columns)
14. `aion_MailList` / `aion_MailRead` / `aion_MailDelete` / `aion_MailGetItem` — full inbox CRUD
15. `aion_MailGetBoxSize` + `aion_MailCheckReceiver_20091007` — send-time validation

**Priority C — abyss UI (optional Q1, required Q2)**:
16. `aion_GetAbyssRankingNew` / `aion_GetAbyssGuildRank` — top-N leaderboards
17. `aion_GetAbyssRanking_For_GuildList` — used by guild-roster screen
18. `aion_SetItemEnchant_20180615` series — enchant outcomes for high-entropy stones

Total Round 6 target: 18 SPs + 1 scaffold-extension migration (~ same volume as Round 5).
