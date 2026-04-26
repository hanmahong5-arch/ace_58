# Entropy Mechanism v1 — Random-Attribute Roll (Round 5 Track C3 Design)

**Status**: DESIGN ONLY. No Lua/Go implementation this round.
**Author**: Round 5 Track C3
**Date**: 2026-04-25
**Land target**: Cycle 17, immediately after Sprint 0 §6.3 confirms client
honours all 10 random_attr slots (user decision: q3 = land Cycle 17).
**Whitepaper anchors**: §2.1 (10 random_attr slots in `user_item_option`),
§3.4 (HIGH safe budget, 6+10 = 16 affix cap), §6.3 (mandatory pre-land test).

> v0 = manastone slot RNG (already implemented Round 4 C2, wired Round 6).
> v1 = the OTHER 10 affix slots — `randomAttr1..10` / `randomValue1..10`.
> Combined entropy makes a 5.8 sword's possible state space exceed 10^25.

---

## 1. attr_id Pool — Source of Truth

### 1.1 Production Evidence (NEGATIVE)

`ai/wiki/raw/47104-final-dump/AionWorldLive/_data/user_item.csv` has **zero**
random_attr columns (random_attr1..10 live in `user_item_option`, which is
NOT in the dump bundle). 5 months of NCSoft 47-server live operation
produced no observable random_attr fills — confirmed by whitepaper §1.1 and
§2.1. **Production cannot inform the attr_id space.**

### 1.2 Client XML Source (POSITIVE)

`tools/ShiguangGate-v1/ncsft-aionweb/conf/gameinfo/item_random_option.xml`
(UTF-16, 1.4 MB, generated 2014-04-15) is the NCSoft GM Tool's own
random-option catalog. After `iconv -f UTF-16 -t UTF-8` it parses to:

- **300 distinct `<item_random_option>` groups** (each represents a set
  of correlated attr rolls for a specific item template).
- **8 999 individual `<random_attrN>` declarations** across all groups.
- **28 unique attr_id names** (case-normalised); 35 raw counting
  upper/lowercase variants of `BoostHate`, `HealSkillBoost`, etc. —
  v1 normalises to lowercase.

This XML is NCSoft's authoritative declaration of "what the 5.8 client
knows how to render in a random_attr slot tooltip" — by definition the
safest possible whitelist.

### 1.3 attr_id Catalog (28 entries, empirical value ranges)

| attr_id | n in xml | empirical [min, max] | category |
|---------|----------|----------------------|----------|
| `phyAttack`               |  938 | [-15, 20]   | offensive |
| `magicalAttack`           |   29 | [-21, 21]   | offensive |
| `magicalSkillBoost`       | 1300 | [-55, 65]   | offensive |
| `healSkillBoost`          |   73 | [1, 35]     | offensive |
| `critical`                |  233 | [1, 30]     | offensive |
| `magicalCritical`         |  341 | [0, 10]     | offensive |
| `hitAccuracy`             |  304 | [1, 40]     | offensive |
| `magicalHitAccuracy`      |  402 | [0, 20]     | offensive |
| `attackDelay`             |  381 | [0, 19]     | offensive |
| `boostCastingTime`        |  172 | [-9, 3]     | offensive |
| `physicalDefend`          | 1320 | [2, 50]     | defensive |
| `magicalResist`           |  407 | [1, 15]     | defensive |
| `magicalSkillBoostResist` | 1517 | [1, 20]     | defensive |
| `block`                   |  112 | [-145, 119] | defensive |
| `parry`                   |  269 | [-98, 107]  | defensive |
| `dodge`                   |   55 | [-53, 10]   | defensive |
| `maxHp`                   |  203 | [-347, 109] | defensive |
| `maxMp`                   |   34 | [-50, 245]  | defensive |
| `arParalyze`              |  240 | [-6, 3]     | resist    |
| `arSilence`               |  100 | [3, 9]      | resist    |
| `paralyze_arp`            |  177 | [-8, 19]    | offensive |
| `silence_arp`             |  233 | [-15, 12]   | offensive |
| `speed`                   |  145 | [1, 2]      | utility   |
| `flySpeed`                |    1 | [2, 2]      | utility   |
| `concentration`           |    5 | [3, 15]     | utility   |
| `boostHate`               |    6 | [-100, 100] | utility   |
| `pvpAttackRatio`          |    1 | [50, 50]    | pvp       |
| `pvpDefendRatio`          |    1 | [50, 50]    | pvp       |

### 1.4 v1 Pool Partitioning

Drop low-evidence outliers (`flySpeed`, `pvpAttackRatio`, `pvpDefendRatio`,
`concentration`, `boostHate` — each ≤6 samples = unsafe to assume the
client renders them in arbitrary slots). v1 ships with 23 attr_ids:

```
offensive = {phyAttack, magicalAttack, magicalSkillBoost, healSkillBoost,
             critical, magicalCritical, hitAccuracy, magicalHitAccuracy,
             attackDelay, boostCastingTime, paralyze_arp, silence_arp}
defensive = {physicalDefend, magicalResist, magicalSkillBoostResist,
             block, parry, dodge, maxHp, maxMp}
resist    = {arParalyze, arSilence}
utility   = {speed}
```

Production-validated empirical ranges from §1.3 become the per-attr value
buckets — v1 quantises each range into 5 evenly-spaced buckets so a "rare"
maxHp roll lands in [-69, 87, 22, 109, ...] = 5 discrete tier-bands rather
than 1 of 456 raw integers (entropy budget vs. tooltip readability tradeoff).

---

## 2. Tier System (parallels v0)

| Tier   | Slots filled (of 10) | Allowed categories | Player feel |
|--------|---------------------|--------------------|-------------|
| common |  4 | offensive ∪ defensive | "Some bonuses" |
| rare   |  7 | + resist             | "Polished gear" |
| epic   | 10 | + utility            | "All ten lines lit" |

v1 fills slots **left-to-right** (slot 1 first, slot 10 last) so a partial
roll always presents `randomAttr1..N` non-NULL and `N+1..10` NULL — matches
the NCSoft production observation that GMs filled 1-2 slots when they did
fill any at all.

**Per-class affix bias** (multiplier applied during weighted draw):

| Class       | offensive | defensive | resist | utility |
|-------------|-----------|-----------|--------|---------|
| warrior     |   1.5     |   1.0     |  1.0   |   0.7   |
| mage        |   1.5     |   0.8     |  1.0   |   1.0   |
| cleric      |   1.0     |   1.5     |  1.2   |   1.0   |
| ranger      |   1.3     |   0.9     |  0.8   |   1.4   |
| sin         |   1.4     |   0.7     |  0.7   |   1.5   |
| chanter     |   1.1     |   1.3     |  1.1   |   1.0   |

Slot-type bias: weapon → 70 % offensive, armor → 70 % defensive, accessory
→ 50 % utility/resist. Bias matrix is the **per-class flavor knob** —
warrior swords feel different from sin daggers without changing item_id.

---

## 3. PRNG — Stream-Independent Sub-Seeding

### 3.1 Why not reuse v0's LCG state

If we naively reuse `entropy.next_lcg(state)` from v0, then per-item the
manastone roll consumes 12 LCG draws (6 stones × pick_tier+pick_stone) and
random_attr would consume the very next 20 draws. The two systems would
share an LCG stream → the two attribute spaces become **statistically
correlated** (rolling 4 epic stones reliably predicts a high crit roll).
Players will spot the correlation and the "1000 hours of surprise" guarantee
collapses.

### 3.2 splitmix64-equivalent in Lua 5.1 LCG

splitmix64 needs bitwise XOR/shifts which gopher-lua lacks. v1 emulates
the same "step a fixed gamma constant, then mix" property using pure
modular arithmetic over 2^31:

```
function entropy.derive_subseed(item_uid, season_seed, stream_id)
    -- stream_id: 0 = manastone (v0), 1..10 = random_attr slot N
    local g = 2654435761    -- golden-ratio prime
    local h = 2246822519    -- second well-distributed prime
    local k = 134775813     -- third (Borland C constant)
    local s = ((item_uid    * g) % 2147483648
            + (season_seed  * h) % 2147483648
            + (stream_id    * k) % 2147483648) % 2147483648
    -- One LCG iteration acts as the "mix" step
    return (s * 1664525 + 1013904223) % 2147483648
end
```

Each random_attr slot 1..10 gets its own derived subseed → 10 independent
LCG streams. Manastone (stream 0) and random_attr slots (streams 1..10) are
provably uncorrelated (different starting points, different LCG trajectories).
**Verification**: a Round-7 statistical test (chi-square over 10⁵ rolls)
must show pairwise mutual information < 0.01 bits between manastone choice
and random_attr1 choice.

### 3.3 Determinism Contract (UNCHANGED from v0)

Same `(item_uid, season_seed)` → same 10-tuple of (attr_id, value).
**No char_id mixing** (user q2 decision: item_uid is canonical fingerprint,
load-bearing for Q3 LLM 叙事 — "this exact sword has been forged 0 times").

---

## 4. Combinatorial Entropy Estimate

Per-item state space (rare tier, weapon class):

```
choose 7 attr_ids from 22 (offensive ∪ defensive ∪ resist):  C(22,7)  = 170 544
ordered into 7 left-to-right slots:                          7!       =   5 040
each slot picks 1 of 5 value buckets:                        5^7      =  78 125
                                                                       ---------
per-item rare-tier random_attr alone:                        ≈ 6.7 × 10^13
combine with v0 manastone (rare tier):                       ≈ 9.0 × 10^9 (per C2 calc)
TOTAL per rare-tier item:                                    ≈ 6 × 10^23
across 4637 distinct item_ids × 6 classes:                   ≈ 1.7 × 10^28
```

**Order of magnitude: 10^25 — 10^28** state space. A QQ group of 100
players opening 1000 chests each over a year (10^5 events) explores
< 10^-20 of the space. Information entropy holds for the project lifetime
by 20 orders of magnitude.

---

## 5. MANDATORY Pre-Land Sprint 0 Client Tests

These five tests MUST pass before any v1 wiring touches dev/. Each
extends the whitepaper §6.3 testing protocol:

1. **§6.3 reproducibility — 10 slots all filled.** Run the exact UPDATE
   from whitepaper §6.3, log into client, count how many tooltip lines
   render. Pass = exactly 10 lines visible. Fail = client crash, missing
   lines, or text overflow off-screen.

2. **Mouseover slot 8 — UI hit-detection.** Hover the cursor over the 8th
   random_attr line in the item tooltip. Pass = tooltip stays open and
   does not flicker. Fail = client crash (5.8 may have hard-coded 6-line
   tooltip allocation).

3. **Negative-value display.** Set `randomValue3 = -50` for an attr that
   accepts negatives (e.g. `phyAttack`). Pass = tooltip shows "-50" with
   correct red coloring. Fail = displays as "+50" (sign stripped) or
   `4294967246` (uint32 underflow).

4. **Character panel stat aggregation.** Equip the test item, open
   character panel (F4), verify the stat increases by exactly the sum of
   values across all 10 random_attr lines (per attr_id semantics). Pass =
   numeric match. Fail = client computes only first 6 (= confirms the
   whitepaper §6.3 prediction that 5.8 caps at 6).

5. **Trade window rendering.** Drop the 10-attr item into a trade window
   with another player. Pass = both client tooltips render all 10 lines
   identically. Fail = trade tooltip uses a different (truncated)
   render-path.

If test 4 fails (client caps at 6), v1 reduces tier sizes to common=3,
rare=5, epic=6 — entropy estimate drops to 10^21 which is still 15 orders
of magnitude over the demand curve. The design is robust to this fallback.

---

## 6. Files NOT Touched This Round

- `scripts/entropy/manastone_pool.lua` — locked v0
- `scripts/entropy/manastone_roll.lua` — locked v0
- `sql/migration-plan/entropy-v0-design.md` — locked v0
- All SQL files (B3 territory)

## 7. Files To Be Created Next Round (Cycle 17 prototype)

```
scripts/entropy/random_attr_pool.lua    -- 23 attr_id catalog + value buckets
scripts/entropy/random_attr_roll.lua    -- 10-slot weighted draw
scripts/entropy/class_bias.lua          -- 6×4 multiplier matrix
internal/luahost/entropy_random_attr_test.go
sql/migration-plan/entropy-v1-wiring-plan.md
```

Bridge extension: `player.add_item_with_options` already accepts the
stones table; v1 adds an optional 5th arg (table of `{attr_id, value}`
pairs, length 10) — same backwards-compat opt-in pattern as v0.

---

## 8. Open Question for User

**Should the affix bias matrix be class-aware (warrior vs mage, today's
spec) OR class+race-aware (Asmodian warrior favors `paralyze_arp`,
Elyos warrior favors `silence_arp`)?** The latter doubles the bias
matrix to 12×4 = 48 cells but creates faction-distinguishable "feel" —
a load-bearing element if Q3 LLM 叙事 is going to narrate "this is an
unmistakably Asmodian blade".
