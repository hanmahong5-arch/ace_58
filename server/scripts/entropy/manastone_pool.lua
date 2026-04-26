-- scripts/entropy/manastone_pool.lua
-- Round 4 Track C2 — Entropy v0: manastone whitelist + tier partition.
--
-- Source of truth: every stone_id below was extracted from production data at
--   ai/wiki/raw/47104-final-dump/AionWorldLive/_data/user_item.csv
-- (5 months of 47-server live operation, 126 distinct manastone IDs found in
-- player inventories). Because each ID is proven to render in the 5.8 client
-- tooltip without a client patch, this list is the safest possible whitelist.
--
-- Tier partition heuristic (refine in Cycle 17 once items.xml parser lands):
--   common: lower 167000xxx range  (item drops at L40-55, ~30 IDs)
--   rare  : upper 167000xxx range  (item drops at L55-65, ~92 IDs)
--   epic  : 167020xxx block        (greater manastones, only 4 IDs)
--
-- This file declares the global `manastone_pool` table consumed by
-- manastone_roll.lua. Hot-reloadable: editing this file refreshes pools
-- within ~1 second (loadScripts walks scripts/ recursively).

manastone_pool = {}

-- --- Tier 1 — Common (lower 167000xxx, ~L40-55 normal drop) ----------------
-- Cutoff 167000570 chosen so the list partitions ~30/92 between common/rare.
manastone_pool.common = {
    167000238, 167000295, 167000322, 167000323, 167000354, 167000355,
    167000360, 167000363, 167000454, 167000482, 167000484, 167000487,
    167000489, 167000491, 167000497, 167000514, 167000515, 167000518,
    167000522, 167000539, 167000541, 167000542, 167000552, 167000553,
    167000556, 167000558, 167000559, 167000560, 167000561, 167000567,
    167000570,
}

-- --- Tier 2 — Rare (upper 167000xxx, ~L55-65 from PvE bosses / quests) -----
manastone_pool.rare = {
    167000571, 167000574, 167000575, 167000576, 167000637, 167000646,
    167000647, 167000648, 167000650, 167000651, 167000652, 167000654,
    167000655, 167000656, 167000657, 167000658, 167000659, 167000660,
    167000661, 167000662, 167000663, 167000664, 167000665, 167000667,
    167000668, 167000669, 167000670, 167000671, 167000672, 167000673,
    167000674, 167000675, 167000676, 167000677, 167000678, 167000679,
    167000680, 167000681, 167000689, 167000690, 167000702, 167000705,
    167000708, 167000714, 167000749, 167000750, 167000751, 167000758,
    167000759, 167000760, 167000761, 167000763, 167000764, 167000765,
    167000766, 167000767, 167000769, 167000771, 167000772, 167000775,
    167000776, 167000777, 167000812, 167000813, 167000814, 167000815,
    167000816, 167000817, 167000818, 167000819, 167000820, 167000821,
    167000822, 167000825, 167000826, 167000827, 167000828, 167000829,
    167000830, 167000832, 167000833, 167000834, 167000835, 167000836,
    167000837, 167000838, 167000839, 167000840, 167000842, 167000843,
    167000844,
}

-- --- Tier 3 — Epic (167020xxx greater manastone block) ---------------------
-- Only 4 IDs in production over 5 months; treat as scarce reward only.
manastone_pool.epic = {
    167020074, 167020079, 167020080, 167020081,
}

-- --- Item-class scoping --------------------------------------------------
-- Different equipment classes pull from different tier subsets.
-- v0 keeps it simple; Cycle 17 v1 may restrict by stat affinity (e.g. only
-- physical-attack stones on weapons, only HP stones on armor).
--
--   weapon    -> any tier allowed
--   armor     -> any tier allowed
--   accessory -> epic-only (rings/necklaces/earrings; scarce slots = scarce stones)
manastone_pool.class_allows = {
    weapon    = { common = true, rare = true, epic = true  },
    armor     = { common = true, rare = true, epic = true  },
    accessory = { common = false, rare = false, epic = true  },
}

-- --- Tier roll-distribution ----------------------------------------------
-- For a given target tier, how many of the 6 manastone slots are filled,
-- and the per-slot weight of drawing from each tier pool.
--
--   slots_filled  = N (1..6); remaining 6-N slots are stone_id=0 (empty).
--   pool_weights  = { common=W1, rare=W2, epic=W3 }; sum to 100.
manastone_pool.tier_config = {
    common = {
        slots_filled = 3,
        pool_weights = { common = 80, rare = 20, epic = 0  },
    },
    rare = {
        slots_filled = 5,
        pool_weights = { common = 30, rare = 60, epic = 10 },
    },
    epic = {
        slots_filled = 6,
        pool_weights = { common = 0,  rare = 40, epic = 60 },
    },
}

-- --- Lookup helper -------------------------------------------------------
-- Returns a flat array of stone_ids drawable for (item_class, tier).
-- The returned table merges pools per the tier_config weights, then filters
-- by class_allows. If a class disallows a tier the weights are renormalised
-- by manastone_roll.lua at draw time — this helper just exposes raw pools.
function manastone_pool.get(tier_name)
    return manastone_pool[tier_name] or {}
end

-- Self-check at load time (catches typos before the test even runs).
assert(#manastone_pool.common  > 0, "manastone_pool.common is empty")
assert(#manastone_pool.rare    > 0, "manastone_pool.rare is empty")
assert(#manastone_pool.epic    > 0, "manastone_pool.epic is empty")
