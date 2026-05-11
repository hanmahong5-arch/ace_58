-- scripts/npcs/mob_215001.lua
-- Round 11 B8 — content seed: hostile mob "Forest Wisp".
--
-- 第一只可被击杀掉落的怪物 (cycle 16 之前 scripts/npcs/* 全是 dialog NPC，
-- 没有"打→死→掉东西"路径)。本文件只声明 mob 模板元数据 (hp/level/loot
-- table 引用) 并注册到全局 mob 表；实际伤害/死亡 broadcast 走 on_kill.lua
-- 已有路径，不重复实现。
--
-- 设计取舍:
--   * 不在本文件定义 on_attacked 主动反击 — 反击逻辑放到 cm_attack.lua
--     handler 路径上一个 hook 更合适，避免每只 mob 都 copy 一份
--     反击代码 (DRY)。本 stub 暴露 react_skill_id 字段供未来 hook 读取。
--   * loot table 定义放到 scripts/data/loot_tables.lua (A8 的 lib/loot.lua
--     消费方)，本文件只标识 loot_table_id = mob_id。
--   * level 5 / hp 250 是 lvl 5 玩家普通攻击 ~3 击 KO 的 PvE 节奏 (新手
--     friendly), 来自 NCSoft starter mob 经验值。
--
-- TemplateID 215001 隶属 21xxxx Verteron Elyos starter mob 段
-- (NCSoft 数据集合此区段为 lvl 1-10 wisp/worg)。我方私服自有 ID 空间
-- 完全独立，与 client npcs.xml 无强约束 — 客户端拿到一个未知 template
-- 会用 fallback 模型显示，不影响协议合法性 (S2 audit 第 4 节)。

mob = mob or {}
mob._templates = mob._templates or {}

-- mob.register(def)
--   def fields:
--     id              (number, required) NPC template ID
--     name            (string)           display name
--     level           (number)           level for EXP / hit-chance scaling
--     hp              (number)           max HP at spawn
--     loot_table_id   (number)           key into loot.register_table; defaults to id
--     react_skill_id  (number)           skill ID to use when attacked (0 = passive)
--     ai              (string)           "passive" | "reactive" | "aggressive"
function mob.register(def)
    if not def or type(def.id) ~= "number" then
        if log and log.warn then log.warn("mob.register: missing id") end
        return false
    end
    mob._templates[def.id] = def
    return true
end

-- mob.get(template_id) -> template_table | nil
function mob.get(template_id)
    return mob._templates[template_id]
end

-- ----------------------------------------------------------------------------
-- Forest Wisp — first hostile mob.
-- ----------------------------------------------------------------------------
mob.register({
    id              = 215001,
    name            = "Forest Wisp",
    level           = 5,
    hp              = 250,
    loot_table_id   = 215001,
    react_skill_id  = 1002,   -- Quick Slash (skills/skill_1002.lua)
    ai              = "reactive",
})
