# Entropy v0 Wiring Plan — Round 6 Apply List

**Status**: Ready to apply. DO NOT apply this round (Round 5 C3) — Track B3
must first port `aion_AddItemUserWithOptions` SP, OR Round 5 may apply with
the bridge in pass-through mode (entropy logged only, no DB effect).

**Author**: Round 5 Track C3
**Depends on**:
- `scripts/entropy/manastone_pool.lua` (Round 4 C2)
- `scripts/entropy/manastone_roll.lua` (Round 4 C2)
- `scripts/entropy/add_item_helper.lua` (this round)
- `internal/luahost/bridge.go` `player.add_item_with_options` (this round)

---

## Tier / item_class Assignment Per Call Site

The four call sites differ in how rewarding they should feel. Tier choices
match the entropy v0 design §3 (common = 3 stones, rare = 5, epic = 6).

| Site | item_class | tier | Rationale |
|------|-----------|------|-----------|
| mail.lua:234 | weapon | common | System mail attachment — neutral, mass-distributed reward |
| shop.lua:40 | weapon | common | Player-purchased — should feel modest unless shop logic later upgrades it |
| quest_10001.lua:26 | weapon | rare | Starter sword — first impression item, deserves "wow" |
| quest_10001.lua:27 | armor | rare | Starter armour — same reasoning |
| instance.lua:519 | weapon | epic | Instance boss reward — peak entropy moment |

Item-class detection (weapon vs armor vs accessory) is a Cycle-17 task once
M4 platform/ exposes `item.xml category` lookup. v0 hard-codes per call site.

---

## Diff #1 — `scripts/lib/mail.lua` line 234

```lua
-- BEFORE:
        player.add_item(gw, iid, icnt)
-- AFTER:
        entropy.add_item_with_stones(gw, iid, icnt, "weapon", "common", season_seed())
```

Helper `season_seed()` to be added in `scripts/lib/api.lua` returning
`world.config().entropy.season_seed` (defaulting to `0xC0FFEE`).

---

## Diff #2 — `scripts/lib/shop.lua` line 40

```lua
-- BEFORE:
    player.add_item(ctx.gateway_seq_id, item_id, count)
-- AFTER:
    entropy.add_item_with_stones(ctx.gateway_seq_id, item_id, count, "weapon", "common", season_seed())
```

---

## Diff #3a — `scripts/quests/quest_10001.lua` line 26

```lua
-- BEFORE:
            player.add_item(gw, 100000001, 1)  -- Starter Sword
-- AFTER:
            entropy.add_item_with_stones(gw, 100000001, 1, "weapon", "rare", season_seed())  -- Starter Sword (5 manastones)
```

## Diff #3b — `scripts/quests/quest_10001.lua` line 27

```lua
-- BEFORE:
            player.add_item(gw, 110000001, 1)  -- Starter Armour
-- AFTER:
            entropy.add_item_with_stones(gw, 110000001, 1, "armor", "rare", season_seed())  -- Starter Armour (5 manastones)
```

---

## Diff #4 — `scripts/lib/instance.lua` line 519

```lua
-- BEFORE:
                                player.add_item(gw, it.id, it.count)
-- AFTER:
                                entropy.add_item_with_stones(gw, it.id, it.count, "weapon", "epic", season_seed())
```

(Future refinement: instance reward table should declare `item_class` per
drop entry — placeholder "weapon" is acceptable while instance.lua is the
only epic-tier emitter.)

---

## Round 6 Apply Checklist

1. Apply 5 diffs above (4 files, 5 lines).
2. Add `season_seed()` helper to `scripts/lib/api.lua`.
3. Add `[entropy]` section to `dev/config/world.toml` and `prod/config/world.toml`:
   ```toml
   [entropy]
   season_seed = 0xC0FFEE  # change to rotate meta each season
   ```
4. Run `go test ./...` from `server/src/` — all 315+ tests must pass.
5. Manual dev smoke: log into dev server, run `/quest start 10001`, complete
   quest, screenshot starter sword tooltip → expect 5 manastone lines.
6. After 24h dev burn-in with no client crashes, promote to prod.

## Rollback

If client crashes appear: revert the 5 diffs (helper file may stay; it
becomes inert once no caller references it). Bridge function and Lua
module can stay — they are zero-overhead when uncalled.
