-- scripts/entropy/add_item_helper.lua
-- Round 5 Track C3 — entropy v0 wiring helper.
--
-- Single point of integration between v0 manastone RNG and the existing
-- player.add_item bridge. Round 6 will switch the four legacy call sites
-- (mail.lua:234, shop.lua:40, quest_10001.lua:26-27, instance.lua:519)
-- from `player.add_item(...)` to `entropy.add_item_with_stones(...)`.
--
-- Contract (locked — Track B3 must NOT change the signature):
--   entropy.add_item_with_stones(gw, item_id, count, item_class, tier, season_seed)
--
--   gw          (number) — gateway_seq_id; same first arg as player.add_item
--   item_id     (number) — items.xml ID
--   count       (number) — stack amount (≤ 1e9 per whitepaper §3.4)
--   item_class  (string) — "weapon" | "armor" | "accessory"
--   tier        (string) — "common" | "rare" | "epic"
--   season_seed (number) — per-season constant from world.toml [entropy].season_seed
--
-- Determinism note: the helper does NOT know item_uid yet (it is allocated
-- by the SP after INSERT). For Round 5 staging we seed the roll with
-- gw + item_id + count as a *placeholder* — the canonical (item_uid,
-- season_seed) seeding moves into the SP itself once aion_AddItemUserWithOptions
-- lands. The placeholder is documented as intentionally unstable so no
-- Lua caller starts depending on the Round-5 stone choice; only Round-6
-- callers will see deterministic-by-item_uid output.

entropy = entropy or {}

-- entropy.season_seed() -> number
--
-- 季节种子 = ISO 周编号（自 Unix epoch 起算的整周数）。
-- 同一周内 season_seed 恒定，跨周自动滚动 — 实现"每周高熵机制刷新"
-- 而无需任何配置改动或服务重启。
--
-- 沙盒约束：vm.go 的 openSafeLibs 只暴露 os.time()（不暴露 os.date），
-- 故用整数除以 604800（每周秒数）实现 ISO 周近似。Cycle 17 以后若需要
-- 严格 ISO 周（按周一对齐），改读 [entropy].season_seed 配置项即可。
function entropy.season_seed()
    local t = os.time and os.time() or 0
    return math.floor(t / 604800)
end

-- 兼容性：Round 6 wiring 用裸 season_seed() 调用，故注册一个全局别名。
-- 这样 mail.lua / shop.lua / quest_10001.lua / instance.lua 不需要写
-- entropy.season_seed() 这种长前缀，可读性好。
function season_seed()
    return entropy.season_seed()
end

-- entropy.add_item_with_stones — see contract above.
-- Returns nothing (matches player.add_item void contract).
function entropy.add_item_with_stones(gw, item_id, count, item_class, tier, season_seed)
    -- Defensive defaults so a caller that forgets the entropy args still
    -- gets a working item grant (degraded to legacy add_item path).
    item_class  = item_class  or "weapon"
    tier        = tier        or "common"
    season_seed = tonumber(season_seed) or 0

    -- Roll the 6-stone tuple. Placeholder seeding keyed on (gw,item_id,count)
    -- — Round 6 SP rewire replaces this with item_uid post-INSERT.
    local placeholder_uid = (tonumber(gw) or 0) * 1000003
                          + (tonumber(item_id) or 0) * 1009
                          + (tonumber(count) or 0)
    local stones = entropy.roll_manastones(
        placeholder_uid, item_class, tier, season_seed)

    -- Round 8 C6 — v3 季节池: 调整非空槽数。
    -- pool.stone_delta = -1 时把末尾非空槽清零；+1 时尝试在最后空槽
    -- 补一颗 common 矿石。本设计选择"事后裁剪"而非"事前改 cfg.slots_filled"
    -- 是为了不破坏 manastone_roll 的 LCG state stream — 同 placeholder_uid
    -- 在 v3 关闭/打开时前 N 个槽完全相同，方便回归对比。
    if entropy.season_pool then
        local pool = entropy.season_pool.active_pool(season_seed)
        if pool and pool.stone_delta and pool.stone_delta ~= 0 then
            local non_empty = 0
            for i = 1, 6 do if stones[i] and stones[i] ~= 0 then non_empty = non_empty + 1 end end
            local target = entropy.season_pool.apply_to_stones(non_empty, pool)
            if target < non_empty then
                -- void_drift / -1: 从尾向前裁
                local cut = non_empty - target
                for i = 6, 1, -1 do
                    if cut <= 0 then break end
                    if stones[i] and stones[i] ~= 0 then
                        stones[i] = 0
                        cut = cut - 1
                    end
                end
            elseif target > non_empty then
                -- lucky_seven / +1: 从头找空槽补一颗 common
                local add = target - non_empty
                local fallback_pool = manastone_pool and manastone_pool.common or nil
                if fallback_pool and #fallback_pool > 0 then
                    for i = 1, 6 do
                        if add <= 0 then break end
                        if not stones[i] or stones[i] == 0 then
                            -- 用 placeholder_uid 派生确定性 idx，stream_id=200 隔离
                            local mix = (placeholder_uid * 1051 + (season_seed or 0) * 200 + i) % #fallback_pool
                            stones[i] = fallback_pool[mix + 1]
                            add = add - 1
                        end
                    end
                end
            end
        end
    end

    -- Round 7 C5: 算 forge ID + 检测 synergy。v0 路径只有 stones 没 attrs；
    -- "全能" set 走 stone:<id> 维度计数（≥6 不同槽位 = 命中）。
    if entropy.forge_id then
        local forge_id = entropy.forge_id({
            item_id = item_id, count = count, race = 0,
            season_seed = season_seed, stones = stones, attrs = {},
        })
        local synergies = entropy.detect_synergy and
            entropy.detect_synergy(stones, {}) or {}
        if log and log.info then
            log.info(string.format(
                "[forge] manastone iid=%d cnt=%d cls=%s tier=%s -> %s synergy=%s",
                tonumber(item_id) or 0, tonumber(count) or 1,
                tostring(item_class), tostring(tier),
                forge_id,
                entropy.summarize_synergies and
                    entropy.summarize_synergies(synergies) or "(?)"))
        end
    end

    -- Hand off to the bridge stub. In Round 5 this still calls legacy
    -- aion_AddItemUser under the hood; the stones are LOGGED (visible in
    -- world debug log) so we can prove the wiring is live before flipping
    -- the SP target.
    player.add_item_with_options(gw, item_id, count, stones)
end

-- Note on load-time self-check: WalkDir loads scripts/entropy/ alphabetically
-- (add_item_helper.lua < manastone_pool.lua < manastone_roll.lua), so we
-- CANNOT assert entropy.roll_manastones at load time — it does not exist
-- yet. The dependency is verified at first-call time inside the function
-- body (Lua resolves entropy.roll_manastones at call-site, not load-site).
-- The Go test entropy_add_item_helper_test.go performs the full end-to-end
-- check after all scripts load.
