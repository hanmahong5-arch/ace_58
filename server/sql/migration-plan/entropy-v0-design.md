# Entropy Mechanism v0 — Manastone Slot RNG (Round 4 Track C2)

**Status**: Staged for Round 5 wiring (do NOT enable in prod yet — depends on
Track B2 porting `aion_AddItemUser` SP variant that accepts manastone slots.)

**Author**: Round 4 Track C2
**Date**: 2026-04-25
**Whitepaper reference**: `doc/business/client-capability-whitepaper-20260425.md`
§3.4 Affix (HIGH but 6+10 capped) and §6.2 6-manastone test.

---

## 1. Goal — Same Sword, Different Soul

> Player gets a sword (item_id 100002 "Iron Sword"). Same client model, same
> tooltip name. But across 1000 players, no two swords have the same affix
> distribution. Driven entirely by **server-side RNG** at item creation. Zero
> client patch. The 5.8 client already reads `manastone1..6` from
> `user_item_option`; we are simply **filling slots NCSoft left at 0**.

Whitepaper §3.4 confirms: 4 637 used item_ids × 6 manastone slots × ~120
verified stone IDs = 10^15 unique configurations even before random_attr is
touched. Cycle 16 v0 uses **only the 6 manastone slots** (random_attr deferred
to v1 once Sprint 0 §6.3 confirms client honours all 10).

---

## 2. Stone Pool — Source of Truth

All stone IDs in this design were **mined from production data** at
`ai/wiki/raw/47104-final-dump/AionWorldLive/_data/user_item.csv` by the SQL:

```sh
grep -oE ",167[0-9]{6}," user_item.csv | sort -u
```

**126 unique stone IDs** are present in real player inventories on the 47 server
across 5 months of operation. This is the safest possible whitelist: each ID is
proven to render correctly in the 5.8 client tooltip without client patching.

The full list is embedded in `scripts/entropy/manastone_pool.lua`. See that
file for tier classification heuristics (the `167000xxx` block is L60-65 white
manastones, `167020xxx` is the higher-grade greater manastone block — only 4
distinct IDs in production = treated as "epic-only" pool).

### Tier Pool Partition

| Tier | Stone block | Count | Source heuristic |
|------|-------------|-------|------------------|
| common | 167000238..167000570 | ~30 | Lower 167000xxx range; widely held |
| rare   | 167000571..167000844 | ~92 | Mid/upper 167000xxx; rarer drops |
| epic   | 167020074..167020081 | 4   | The exclusive 167020xxx block (greater manastones) |

> **Calibration TODO**: tier boundaries are heuristic — once `item.xml` parsing
> lands in M4 platform/, replace with `level >= 60 AND grade='Heroic'` query.

---

## 3. Tier System — Drop Probability and Fill Rate

The tier of a freshly-spawned item is determined by the caller (loot-drop
table, quest reward, shop, mail). v0 supports three tiers; the roll function
takes the tier as input and decides:

- **how many** of the 6 slots get filled
- **which pool** the stones are drawn from

| Tier | Slots filled | Pool weights (common/rare/epic) | Player feel |
|------|--------------|---------------------------------|-------------|
| common | 3 | 80% / 20% / 0% | "OK, three minor bonuses" |
| rare   | 5 | 30% / 60% / 10% | "Wow, this thing has 5 stones" |
| epic   | 6 | 0% / 40% / 60% | "Six greater manastones — keep this!" |

Empty slots are encoded as stone_id = 0 (matches the production-dump default
in `user_item_option.manastone1..6`).

---

## 4. RNG — Determinism + Verifiability

### 4.1 Why deterministic?

Players will (eventually) screenshot affix combos and post in QQ groups.
"Why does my sword have different stones than yours when we both opened the
same chest?" must be answerable: **different (item_uid, season_seed) tuple →
different roll, by design**. Same tuple **always** produces the same roll —
this lets the AI dungeon master narrate "this exact sword has been forged 0
times before" with cryptographic certainty.

### 4.2 PRNG choice

**xorshift64** (Marsaglia 2003) implemented in pure Lua 5.1 (gopher-lua hosts
Lua 5.1; see `internal/luahost/vm.go`). xorshift64 is:

- 64-bit state, period 2^64 − 1 (vastly more than we need)
- ~4 ops per draw, no allocations
- Reproducible across Go/Lua/PG (we can re-implement the same step in PG SP for
  audit later)
- **Not** cryptographically secure — irrelevant; players cannot predict
  `item_uid` ahead of creation.

> Why not `math.random`? gopher-lua's `math.random` shares a single global
> state across all VMs in the pool. That breaks determinism the moment two
> rolls run on different VMs. Local xorshift state in the call stack is
> immune.

### 4.3 Seed derivation

```
seed = xorshift64_mix(item_uid XOR rotate_left(season_seed, 17))
```

- `item_uid` = the `user_item.id` row PK (assigned by DB after insert; see
  hook-point note §6).
- `season_seed` = a per-server-season constant in `world.toml`
  (`[entropy].season_seed = 0xC0FFEE`). Changing it invalidates all caches —
  used to roll over high-entropy meta every season without code change.

### 4.4 Affix-pool concept (item_class scoping)

Different equipment classes accept different stone subsets. v0 uses three
classes — extensible by Round 5:

| item_class | Allowed pool | Rationale |
|------------|-------------|-----------|
| weapon     | full pool   | Weapons benefit from any stat |
| armor      | full pool   | Same |
| accessory  | epic-only   | Accessory slots are scarce; reward feel |

The Lua function takes `item_class` as a string param; pool lookup is a table
read in `manastone_pool.lua`.

---

## 5. Verification Protocol (Round 5 will execute)

Before enabling on prod, Round 5 must:

1. Run `entropy_manastone_test.go` — must pass (TDD ground truth).
2. Manually craft a single rare-tier sword in dev, log into client, screenshot
   tooltip → verify all 5 manastone lines render (whitepaper §6.2).
3. Run for 24h on dev with 10 NPCs dropping random items → no client crash, no
   GM ticket about "missing item icon".

---

## 6. Hook Point — Where Round 5 Wires It

The single canonical item-grant API today is the Go bridge function
`player.add_item(gateway_seq_id, item_id, count)` defined in
`server/src/internal/luahost/bridge.go:604`.

Round 5 must extend this **without** breaking the existing 4 callers
(`mail.lua:234`, `quest_10001.lua`, `shop.lua:40`, `inst_300320000_beshmundir.lua`):

### Recommended evolution (NOT in this round):

1. Introduce `player.add_item_with_entropy(gw_seq_id, item_id, count, item_class, tier)`
   in `bridge.go` that calls a new SP variant `aion_AddItemUserWithOptions`.
2. The new SP atomically:
   - inserts into `user_item` returning the freshly-allocated `id` (= `item_uid`)
   - calls Lua via callback (or replicates xorshift in PL/pgSQL — preferred for
     atomicity) to roll 6 stone_ids
   - inserts into `user_item_option` with all 6 manastone slots populated
3. Existing `player.add_item` stays unchanged → `tier='common', item_class='weapon'`.

The Lua side **prototype** call site (post-wiring) is exactly:

```lua
-- shop.lua:40 (before wiring):
player.add_item(ctx.gateway_seq_id, item_id, count)

-- shop.lua:40 (after Round 5 wiring):
local stones = entropy.roll_manastones(item_uid, item_class, "common", season_seed)
player.add_item_with_options(ctx.gateway_seq_id, item_id, count, stones)
```

But the round-4 design **does not** add the wiring — it only stages
`scripts/entropy/` so Round 5 can pull the trigger after Track B2 ports the
SP.

---

## 7. Open Questions for the User

1. **Should rare drops weight high-value stones more?** Current §3 has rare =
   30/60/10 (common/rare/epic). Should it be 20/60/20 to give rare a chance
   at greater manastones?
2. **Per-character seed?** Right now (item_uid XOR season_seed) means two
   players who both spawn item_uid 12345 from the same chest get identical
   stones. Should we mix in `char_id` so even same-uid items differ per
   player? (Tradeoff: breaks the "uid = canonical fingerprint" property.)
3. **Random_attr v1 timing?** The 10 random_attr slots are ~10x the entropy
   space of manastones. Should v1 land Cycle 17 (right after Sprint 0
   §6.3 confirms client honours all 10 slots) or wait until v0 has 1 month
   of player feedback?

---

## 8. Files Created This Round

```
ACE_5.8/server/sql/migration-plan/entropy-v0-design.md       (this file)
ACE_5.8/server/scripts/entropy/manastone_pool.lua            (126-stone whitelist + tier sets)
ACE_5.8/server/scripts/entropy/manastone_roll.lua            (xorshift64 + roll_manastones)
ACE_5.8/server/src/internal/luahost/entropy_manastone_test.go (3 determinism / diversity / pool tests)
```

No production code is modified. No SP is touched. No Go bridge is changed.
Round 5 picks up from here.
