-- scripts/entropy/forge_id.lua
-- Round 7 C5 — entropy v2 锻造编号 (Forge ID)。
--
-- 每件高熵装备拥有一个 8 字符大写 hex"锻造编号"。同 (item_id, count, race,
-- season_seed, stones, random_attrs) 输入 → 同 ID（确定性）；不同输入 → 几乎
-- 必然不同 ID（SHA1 截断 4 字节，碰撞期望 ~65k 输入后才发生）。
--
-- 用途：
--   1) 玩家 QQ 群晒装备时引用："看我这把 F0RGE042 — 雷霆重击 + 全能"
--   2) LLM 涌现叙事可用 ID 锚定具体装备 (Q3 起)
--   3) 后端调试 / 客服定位单件装备来源
--
-- API:
--   entropy.forge_id(item_data) -> "ABCDEF12"
--     item_data 是 table，可包含字段:
--       item_id     (number) — 必填
--       count       (number) — 默认 1
--       race        (number) — 默认 0 (无种族偏置)
--       season_seed (number) — 默认 0
--       stones      (number[]) — 1..6, 0 = 空槽
--       attrs       (array of {attr_id=string, value=number})
--
--   entropy.print_forge_id(item_data) -> string
--     生成 ID 并通过 log.info 打印 "[forge] iid=<X> -> <ID>"，方便 dev/调试。
--
-- 实现要点：
--   * 真正 hash 在 Go bridge (entropy.forge_id 全局函数) 完成，
--     Lua 这边只是参数检查 + 默认填充
--   * Lua bridge 函数已注册为 entropy.forge_id (全局 entropy 表)，本文件
--     扩展同表的 helper 函数 — 注意 entropy = entropy or {} 防止覆盖

entropy = entropy or {}

-- 保存 Go 注入的原生 forge_id (在 Bridge.Register 时注册)。Bridge 注册时
-- 整个 entropy 表是新的，所以 Go-side 函数必然先存在 — 但 hot-reload 时
-- 这个文件可能在新 VM 里先于其它脚本执行，故用条件捕获保护。
local _native_forge_id = entropy.forge_id

function entropy.forge_id(item_data)
    -- 规范化默认值，避免 Go 一侧的 optInt 漏网（Go 容错存在但显式更安全）
    item_data = item_data or {}
    local spec = {
        item_id     = tonumber(item_data.item_id)     or 0,
        count       = tonumber(item_data.count)       or 1,
        race        = tonumber(item_data.race)        or 0,
        season_seed = tonumber(item_data.season_seed) or 0,
        stones      = item_data.stones or {},
        attrs       = item_data.attrs or {},
    }
    if _native_forge_id then
        return _native_forge_id(spec)
    end
    -- 兜底: 如果 Go bridge 缺失（不可能但防御性），返回稳定占位 ID
    return "00000000"
end

-- print_forge_id: 生成 + log。返回 ID 给上游链式使用。
function entropy.print_forge_id(item_data)
    local id = entropy.forge_id(item_data)
    if log and log.info then
        log.info(string.format(
            "[forge] iid=%d cnt=%d race=%d -> %s",
            tonumber((item_data or {}).item_id) or 0,
            tonumber((item_data or {}).count)   or 1,
            tonumber((item_data or {}).race)    or 0,
            id))
    end
    return id
end

-- 自检: load 时调用一次，确认 Go bridge 已注入且不 panic。
do
    local probe = entropy.forge_id({
        item_id = 100000001, count = 1, race = 2, season_seed = 0xC0FFEE,
        stones = {1001, 0, 0, 0, 0, 0},
        attrs  = {{attr_id="phyAttack", value=10}},
    })
    assert(type(probe) == "string" and #probe == 8,
        "entropy.forge_id must return 8-char string, got " .. tostring(probe))
end
