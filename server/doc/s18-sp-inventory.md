# Phase S-18 — Stored-Procedure Inventory (Auction / Mail / Kinah / Item-Transfer)

Source catalog: `server/doc/migration/procedures/aion_world_live_procedures.sql` (~1063 functions).
Generated for Phase S-17 → S-18 transition to bridge Lua skeletons to real SPs.

Search patterns (case-insensitive):
`aion_.*[Aa]uction.*`, `aion_.*[Mm]ail.*`, `aion_.*[Kk]inah.*`, `aion_.*[Ii]tem.*[Tt]rans.*`

---

## 1. Existing SPs

### Auction (13 hits)

| Line | Function | Purpose (inferred) |
|------|----------|--------------------|
| 273   | `aion_updateauctionstate(...)` | Update listing state |
| 7571  | `aion_addauction(...)` | Create listing |
| 7737  | `aion_addauctionfilterlist(...)` | Filter bookmark |
| 7934  | `aion_addauctiongrace(...)` | Grace-period mail |
| 10523 | `aion_getauctionbettinglist(...)` | Fetch bids for char |
| 10736 | `aion_getauctionfilterlist(...)` | Load filter |
| 10934 | `aion_getauctiongracelist(...)` | Load grace mails |
| 11157 | `aion_getauctionlist_110628(...)` | Paginated browse |
| 11414 | `aion_getauctionstate_20110609(...)` | State lookup |
| 13190 | `aion_setauctionbetting(...)` | Place bid |
| 13339 | `aion_setauctiongrace(...)` | Mark grace |
| 13513 | `aion_setauctionstate(...)` | Write state |
| 24042 | `aion_deleteauctionbetting(...)` | Cancel bid |
| 24202 | `aion_deleteauctionfilterlist(...)` | Delete filter |

### Mail (14 hits)

| Line | Function | Signature Summary |
|------|----------|-------------------|
| 13906 | `aion_mailcheckreceiver_20091007(...)` | verify recipient |
| 14204 | `aion_maildelete(...)` | delete by id |
| 14445 | `aion_mailgetboxsize(...)` | mailbox size |
| 15524 | `aion_mailgetitem(...)` | claim attached item |
| 15716 | `aion_mailgetqueuedmaillist(...)` | queued system mail |
| 15862 | `aion_maillist(...)` | list mails of char |
| 16017 | `aion_mailread(...)` | fetch body |
| 16168 | `aion_mailrestoreitem(...)` | unclaim on error |
| 16308 | `aion_mailsetread(...)` | flip read flag |
| **16515** | **`aion_mailwrite(p_to_id int, p_to_name varchar(20), p_from_id int, p_from_name varchar(20), p_title varchar(20), p_content varchar(1000), p_item_id bigint, p_item_nameid int, p_item_amount bigint, p_money bigint, p_warehouse int, p_arrive_time int, p_express_mail int) RETURNS void`** | **Player-to-player write** |
| 16710 | `aion_mailwrite_20111227(...)` | superseded revision |
| 16958 | `aion_mailwrite_20160804(...)` | superseded revision |
| **17161** | **`aion_mailwritesys_20111227(p_to_id int, p_to_name varchar(20), p_from_id int, p_from_name varchar(20), p_title varchar(20), p_content varchar(1000), p_item_id bigint, p_item_nameid int, p_item_amount bigint, p_money bigint, p_warehouse int, p_arrive_time int, p_express_mail int) RETURNS void`** | **System mail (GM / auction payout / event)** — same 13 args as `aion_mailwrite` |
| 18076 | `aion_getmailasset(...)` | load attachment |

### Kinah (0 hits)

No function matches `aion_.*kinah.*`.
The `bridge.go` code-path calls a placeholder `aion_AddKinahUser` which **does not exist** in the catalog.

Kinah in NCSoft schema is stored as item `name_id = 182400001` in `user_item` (see `aion_getkinaasset` at line 17206 and `gm_useritemdao_updatemoneyforsellrecovery` at line 17191). Any "add kinah" operation must either:
- call an item-level SP to UPDATE `user_item.amount WHERE name_id=182400001`, or
- be implemented as a new SP `aion_addkinahuser(p_char_id int, p_delta bigint)`.

### Item-Transfer (0 hits for `itemtrans`)

No function matches `aion_.*itemtrans.*`.
Related SPs for ownership transfer: `aion_setitemwarehouseonly` (line 14306) and the UPDATE embedded in `aion_mailwrite` (shifts `user_item.char_id` to recipient when mail carries an item).

---

## 2. Verdict: Lua Skeleton → Real SP Mapping

| Lua skeleton call                 | Real SP available? | Replacement |
|-----------------------------------|---------------------|-------------|
| `aion_InsertMailUser` (skeleton)  | **NO** — never deployed | **`aion_mailwritesys_20111227`** (13-arg system-mail variant) |
| `aion_SettleAuction`              | **NO** — missing     | **MUST ADD** (see §3) |
| `aion_AddKinahUser`               | **NO** — missing     | **MUST ADD** (see §3) |
| `aion_AddItemUser`                | not checked here (see S-15 bridge.go TODO) | outside S-18 scope |

Phase S-17 `on_mail_deliver.lua` is updated in this patch to call `aion_mailwritesys_20111227` with the real 13-parameter signature.

`on_auction_expire.lua` is **left calling the missing SP** per the task rules, pending §3 backlog implementation.

---

## 3. SP Backlog for Auction-Settlement Flow (Proposed for S-18)

The canonical settlement (`on_auction_expire.lua` §11-17) requires SPs that do not exist yet. Proposed signatures, matching NCSoft naming conventions and existing `aion_world_live` column types:

### 3.1 `aion_settleauction`

```sql
CREATE OR REPLACE FUNCTION aion_settleauction(
    p_listing_id bigint
) RETURNS TABLE(
    winner_cid   integer,
    seller_cid   integer,
    item_id      bigint,
    item_count   bigint,
    final_bid    bigint,
    outcome_code integer   -- 1 = sold, 0 = expired unsold, -1 = already settled
)
LANGUAGE plpgsql AS $$
-- Atomic resolve of expired auction: read highest bid from auction_betting,
-- mark the auction row as settled, and return the tuple above so the caller
-- (Lua worker) can dispatch mail + kinah transfer. Idempotent — re-calls
-- for an already-settled listing return outcome_code = -1 with zero fields.
$$;
```

### 3.2 `aion_addkinahuser`

```sql
CREATE OR REPLACE FUNCTION aion_addkinahuser(
    p_char_id integer,
    p_delta   bigint      -- may be negative; must not drive balance < 0
) RETURNS bigint          -- new balance, or -1 on insufficient funds for negative delta
LANGUAGE plpgsql AS $$
-- UPDATE user_item SET amount = amount + p_delta
-- WHERE char_id = p_char_id AND name_id = 182400001 AND warehouse = 0
-- RETURNING amount.  Rejects negative deltas that would underflow.
$$;
```

### 3.3 (optional) `aion_insertmailsys`

If the team prefers a clearer name than `aion_mailwritesys_20111227`, add a thin alias:

```sql
CREATE OR REPLACE FUNCTION aion_insertmailsys(
    p_to_id integer, p_to_name varchar(20),
    p_from_id integer, p_from_name varchar(20),
    p_title varchar(20), p_content varchar(1000),
    p_item_id bigint, p_item_nameid integer, p_item_amount bigint,
    p_money bigint, p_warehouse integer,
    p_arrive_time integer, p_express_mail integer
) RETURNS void
LANGUAGE sql AS $$
    SELECT aion_mailwritesys_20111227(
        p_to_id, p_to_name, p_from_id, p_from_name,
        p_title, p_content, p_item_id, p_item_nameid, p_item_amount,
        p_money, p_warehouse, p_arrive_time, p_express_mail);
$$;
```

Not strictly needed — the existing SP already works — but readable.

---

## 4. Integration-Test Gating

Any test that depends on the auction-settlement SPs (§3.1, §3.2) must be **skipped until deployed**.
`TestIntegration_AuctionSettleSmoke` in
`server/src/internal/luahost/integration_pg_test.go` uses `t.Skip(...)` with the exact SP names listed above; once the SPs ship, delete the skip and re-run.

## 4b. Character Lifecycle SPs (Phase S-18b)

Added for CM_CREATE_CHARACTER (0x12) / CM_DELETE_CHARACTER (0x14) handler implementation.

| Line | Function | Purpose | Signature |
|------|----------|---------|-----------|
| 20095 | `aion_checkvalidcharname(p_strName, p_strAccount)` | Pre-create name validation | returns int: 0=ok, -1=duplicate, -2=forbidden, -3=reserved-by-another-account |
| 21667 | `aion_putchar_20160620(80+ cols)` | Insert new character row | returns void; relies on PG SELECT lastval or INSERT ... RETURNING patch post-deploy |
| 16695 | `aion_setchardeletetime(p_nCharId, p_nDeleteTime)` | Schedule soft-delete via UNIX timestamp | 7-day grace enforced by caller |
| 20534 | `aion_clearchardeletetime(p_nCharId)` | Restore character within grace | reserved for future CM_RESTORE_CHARACTER |
| 24661 | `aion_deletechar(p_nCharId)` | Hard-delete from user_data | called by the nightly sweeper job, NOT by CM_DELETE_CHARACTER |

**Findings**: All five SPs exist in the catalog — **no gaps**. The CM handlers call the real SP names verbatim. The `aion_putchar_20160620` SP takes 80+ positional args; the Lua handler supplies the 26 always-relevant fields and relies on PostgreSQL positional defaulting for the `feat_*` slider set (players refine those at the barber-shop NPC later). If the deployed SP rejects partial args, a follow-up patch must add `DEFAULT 0` clauses to the SP signature (tracked under the S-18b migration patch queue).

## 5. Counts Summary

- Auction SPs in catalog: **14**
- Mail SPs in catalog: **14**
- Kinah SPs in catalog: **0**
- Item-Transfer SPs in catalog: **0**

- Lua-referenced SPs that EXIST: `aion_mailwritesys_20111227` (via rename)
- Lua-referenced SPs that are MISSING: `aion_SettleAuction`, `aion_AddKinahUser`
