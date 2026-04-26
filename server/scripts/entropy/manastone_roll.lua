-- scripts/entropy/manastone_roll.lua
-- Round 4 Track C2 — Entropy v0: deterministic manastone roll.
--
-- API:
--   entropy.roll_manastones(item_uid, item_class, tier, season_seed)
--     -> table[6] of stone_ids (some may be 0 = empty slot)
--
-- Determinism contract (asserted by entropy_manastone_test.go):
--   * Same (item_uid, item_class, tier, season_seed) tuple ALWAYS returns
--     the identical 6-tuple. Lets the AI dungeon master narrate "this exact
--     sword has been forged 0 times before" with cryptographic certainty.
--   * Distinct tuples produce diverse rolls (no collision in 1000-sample test).
--   * Every returned non-zero stone_id is in manastone_pool.{common,rare,epic}.
--
-- PRNG choice — LCG over 2^31:
--   gopher-lua hosts Lua 5.1 numerics (float64, no bit32, no integer type).
--   xorshift requires bitwise XOR which is unavailable without the bit lib.
--   A 32-bit LCG (Numerical Recipes constants) with state in [0, 2^31) is
--   exactly representable in float64 with zero rounding loss, needs only
--   *, +, %, math.floor — all float-safe. Period 2^31 is plenty: each item
--   draws 6 stones, so we'd need 357M items per season to exhaust period.
--   LCG quality is OK for game RNG (NOT cryptographically secure, but
--   players cannot predict item_uid ahead of creation, so adversarial
--   prediction is moot).
--
-- Lua 5.1 portability notes:
--   * No `goto` (avoid even though gopher-lua tolerates it)
--   * No integer division `//`; use math.floor(a/b)
--   * No bitwise operators `~ & | <<`; use modular arithmetic
--   * Number type is float64; 2^31 fits exactly

entropy = entropy or {}

-- --- LCG core ------------------------------------------------------------
-- Numerical Recipes 32-bit LCG: x_{n+1} = (1664525 * x_n + 1013904223) mod 2^32
-- We restrict state to 2^31 to stay within float64 safe-integer range when
-- multiplied by 1664525 (max intermediate ~ 1664525 * 2^31 = 3.57e15, well
-- under float64's 2^53 = 9e15 safe-integer ceiling).
local LCG_MUL  = 1664525
local LCG_ADD  = 1013904223
local LCG_MOD  = 2147483648  -- 2^31

-- lcg_next advances the state and returns (new_state, uniform [0,1)).
local function lcg_next(state)
    local s = (state * LCG_MUL + LCG_ADD) % LCG_MOD
    return s, s / LCG_MOD
end

-- mix_seed combines item_uid with season_seed into a 31-bit initial state.
-- We multiply item_uid by a large prime then add season_seed * another prime,
-- then mod into LCG_MOD. Both primes chosen from Knuth's "good multipliers":
--   2654435761 (Knuth multiplicative-hash golden ratio prime)
--   2246822519 (another well-distributed 32-bit prime)
-- The double-multiply-mod pattern avoids correlation when (item_uid,
-- season_seed) increment by 1 each — adjacent inputs map to far-apart seeds.
local function mix_seed(item_uid, season_seed)
    local a = (item_uid    * 2654435761) % LCG_MOD
    local b = (season_seed * 2246822519) % LCG_MOD
    -- Combine via add-then-mod (XOR unavailable; add+mod gives similar
    -- diffusion when both halves are well-distributed).
    local s = (a + b) % LCG_MOD
    if s == 0 then s = 1 end  -- LCG with state=0 stays at LCG_ADD; nudge to avoid degenerate first call
    return s
end

-- --- Pool draw helpers ---------------------------------------------------

-- pick_tier_for_slot draws a tier name (common/rare/epic) per the
-- weighted distribution in manastone_pool.tier_config[tier].pool_weights,
-- but filtered by manastone_pool.class_allows[item_class]. Returns the
-- chosen tier name OR nil if no tier is allowed for this class.
local function pick_tier_for_slot(state, item_class, tier)
    local cfg = manastone_pool.tier_config[tier]
    if not cfg then return state, nil end
    local allows = manastone_pool.class_allows[item_class] or {}

    -- Renormalise weights against the class filter.
    local active = {}
    local total = 0
    for tname, w in pairs(cfg.pool_weights) do
        if w > 0 and allows[tname] then
            active[#active + 1] = { name = tname, weight = w }
            total = total + w
        end
    end
    if total == 0 then return state, nil end

    local s2, r = lcg_next(state)
    local pick = r * total
    local acc = 0
    for i = 1, #active do
        acc = acc + active[i].weight
        if pick < acc then
            return s2, active[i].name
        end
    end
    -- Floating tail safety net.
    return s2, active[#active].name
end

-- pick_stone_from_pool draws a uniform-random stone_id from the named pool.
local function pick_stone_from_pool(state, pool_name)
    local pool = manastone_pool[pool_name]
    if not pool or #pool == 0 then return state, 0 end
    local s2, r = lcg_next(state)
    local idx = math.floor(r * #pool) + 1
    if idx > #pool then idx = #pool end  -- guard against r==1.0 edge (should not happen but harmless)
    return s2, pool[idx]
end

-- --- Public API ----------------------------------------------------------

-- entropy.roll_manastones(item_uid, item_class, tier, season_seed) -> table[6]
--
-- item_uid     (number) — user_item.id PK; the stable per-item identity.
-- item_class   (string) — "weapon" | "armor" | "accessory"
-- tier         (string) — "common" | "rare" | "epic"
-- season_seed  (number) — per-server-season constant from world.toml
--
-- Returns a 6-element array; index N is the stone_id for manastone slot N.
-- Empty slots are encoded as 0 (matches user_item_option default).
function entropy.roll_manastones(item_uid, item_class, tier, season_seed)
    item_uid    = tonumber(item_uid)    or 0
    season_seed = tonumber(season_seed) or 0
    item_class  = item_class or "weapon"
    tier        = tier       or "common"

    local cfg = manastone_pool.tier_config[tier]
    local result = { 0, 0, 0, 0, 0, 0 }
    if not cfg then return result end

    local n_filled = cfg.slots_filled
    if n_filled < 0 then n_filled = 0 end
    if n_filled > 6 then n_filled = 6 end

    local state = mix_seed(item_uid, season_seed)
    for slot = 1, n_filled do
        local tier_name
        state, tier_name = pick_tier_for_slot(state, item_class, tier)
        if tier_name then
            local stone
            state, stone = pick_stone_from_pool(state, tier_name)
            result[slot] = stone
        end
    end
    return result
end

-- Self-check at load: roll a known input, verify it's a 6-table.
do
    local probe = entropy.roll_manastones(1, "weapon", "common", 0xC0FFEE)
    assert(type(probe) == "table" and #probe == 6,
        "entropy.roll_manastones must return a 6-element table")
end
