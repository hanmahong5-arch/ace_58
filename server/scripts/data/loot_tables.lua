-- scripts/data/loot_tables.lua
-- Round 11 B8 — content seed: mob loot table 数据。
--
-- 与 A8 (Round 11 lib/loot.lua engine) 的契约:
--   loot.register_table(mob_id, table_def)
--     table_def = {
--       drops = {
--         { item_id=N, count=N, weight=W, class="weapon|armor|consumable",
--           tier="common|rare|epic" },
--         ...
--       }
--     }
--
-- 本文件仅"定义并注册"数据, 不实现 roll/grant 逻辑 (那部分在 A8 的
-- lib/loot.lua 里)。loadScripts 顺序: lib/* 先于 data/*, 故 A8 的 loot 模块
-- 加载时本文件还没运行; 但 data/* 在 npcs/quests/skills 字母序前 (d < n/q/s),
-- 故 mob 模板已注册即可定位 — 不依赖 npcs/* 先 register。
--
-- 防御性: A8 未落地时 _G.loot 仍是 nil, 直接调用会 panic。我们用 guard
-- 包一层, 让 loot 缺失时本文件依然可加载, 仅 emit 一条 info 日志提示。
-- 这样 B8/C8 与 A8 可以独立 commit, 整套 regression 始终绿。
--
-- 设计取舍 (Forest Wisp 215001):
--   * 武器 100100 (Crude Short Sword): 80% 掉率 — common tier 4 槽 random_attr
--     是新手"第一件熵装备", 高掉率保证玩家几乎一定能拿到, 命题验证度上去。
--   * 消耗品 200100 (Lesser Healing Vial): 30% 掉率 — 不带 affix, 维持血量
--     回复的实用性, 但不溢出 (避免新手背包炸)。
--   * weight 字段: 在 80%/30% 总池内的相对权重 (engine 决定如何插值;
--     A8 接口未规定绝对语义, 我方写 1 即"等权"是最保守安全的默认值)。

-- guard: lib/loot.lua 未加载时静默 noop (A8 未到场)
if not loot or type(loot.register_table) ~= "function" then
    if log and log.info then
        log.info("[data] loot_tables.lua: lib/loot.lua not loaded, skipping registration")
    end
    return
end

-- ----------------------------------------------------------------------------
-- Forest Wisp (mob template 215001)
-- ----------------------------------------------------------------------------
loot.register_table(215001, {
    drops = {
        {
            item_id = 100100,        -- Crude Short Sword
            count   = 1,
            weight  = 80,            -- ~80% 掉落 (engine 总权和决定确切概率)
            class   = "weapon",
            tier    = "common",
        },
        {
            item_id = 200100,        -- Lesser Healing Vial
            count   = 1,
            weight  = 30,            -- ~30% 掉落
            class   = "consumable",
            tier    = "common",
        },
    },
})

if log and log.info then
    log.info("[data] loot_tables.lua: registered mob 215001 with 2 drop entries")
end
