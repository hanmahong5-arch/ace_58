-- scripts/data/items_seed.lua
-- Round 11 B8 — content seed: item template 注册 (Crude Short Sword + Lesser Healing Vial)。
--
-- 与 lib/items.lua 的契约:
--   items.register({ id, name, slot, required_level, attack, defense, hp_bonus })
--     slot: 1=MAIN_HAND ... 0=non-equippable
--
-- 为什么放在 data/ 而非 lib/items.lua:
--   * lib/items.lua 是 A8 owner 不能动 (Round 11 B8 协调约束)
--   * items.register 是公共 API, data/* 加载顺序在 lib/* 之后 (vm.go:283
--     append(libFiles, otherFiles...)), 注册保证可达
--   * 把 seed 数据从 lib 框架剥离也是 SoC 最佳实践 — lib 提供机制,
--     data 提供内容
--
-- 设计参数:
--   * Crude Short Sword (100100): lvl 1 起手剑, attack 25 略弱于 lib/items.lua
--     的 Wooden Sword (30) — 因为本剑会带 random_attr 加成 4 槽, 净期望
--     与 Wooden Sword 同档但波动更大 (= entropy)。
--   * Lesser Healing Vial (200100): non-equippable (slot=0)。HP 回复在
--     consume_item handler 处理, 模板这里不带 hp_bonus (那是装备字段)。

if not items or type(items.register) ~= "function" then
    if log and log.warn then
        log.warn("[data] items_seed.lua: lib/items.lua not loaded — abort")
    end
    return
end

-- Crude Short Sword: 主手武器 (slot 1), lvl 1 准入, base attack 25
items.register({
    id             = 100100,
    name           = "Crude Short Sword",
    slot           = 1,    -- SLOT_MAIN_HAND
    required_level = 1,
    attack         = 25,
    defense        = 0,
    hp_bonus       = 0,
    description    = "A blade rough enough to nick wisps. The base for your first random_attr.",
})

-- Lesser Healing Vial: 消耗品 (slot 0 = non-equippable)
items.register({
    id             = 200100,
    name           = "Lesser Healing Vial",
    slot           = 0,
    required_level = 0,
    attack         = 0,
    defense        = 0,
    hp_bonus       = 0,
    description    = "Restores a little HP when consumed. Drops from Forest Wisps.",
})

if log and log.info then
    log.info("[data] items_seed.lua: registered 2 items (100100, 200100)")
end
