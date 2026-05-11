-- scripts/quests/quest_10002.lua
-- Round 11 B8 — content seed: quest "Wisp in the Glade".
--
-- 第一个"杀怪+回交"型任务 (cycle 16 之前 quest_10001 是纯 starter, 没有
-- 击杀进度跟踪)。本任务把"建号→进世界→对话接任务→击杀→交付奖励"全链
-- 跑一遍, 是 Round 11 命题"高熵闭环"的最小验证用例。
--
-- 流程:
--   1. quest.start (NPC 798010 OPT_ACCEPT) → on_start: 重置 kill_count
--   2. 玩家击杀 mob_215001, 走 on_entity_killed → quest.advance_kill 提升计数
--   3. kill_count 达 3 → quest 进 step 99 (ready to turn in)
--   4. quest.complete (NPC 798010 OPT_TURNIN) → on_complete: 给装备 + EXP
--
-- 设计要点:
--   * kill_count stat 用 "quest_10002_kills" key, 与 quest_10002_state 隔离,
--     方便 GM/调试单独清零。
--   * 奖励武器走 entropy.add_item_with_random_attr ("common" tier 4 槽), 让
--     新手第一件装备就带 random_attr — 命题验证: 玩家从一开始就接触熵机制。
--   * EXP 量 1500 为 lvl 5 → 6 的约 75% (NCSoft pcexp_table.xml 推算), 让玩家
--     交完任务后明显升级一次, 强化"完成任务=正反馈"信号。

local QUEST_ID    = 10002
local TARGET_MOB  = 215001
local KILLS_NEEDED = 3
local REWARD_WEAPON_ID = 100100   -- Crude Short Sword (data/loot_tables.lua 也可掉落)
local REWARD_EXP  = 1500

-- quest 模块 register: 仅声明定义, 不提供 advance_kill 自定义钩 (放到下方
-- 注册后另挂全局 hook 以保持 quest.lua 通用 framework 不污染)。
quest.register({
    id    = QUEST_ID,
    name  = "Wisp in the Glade",
    steps = 2,   -- step 1 = collecting, step 99 = ready

    on_start = function(entity_id)
        -- 进度重置: 即使玩家之前接过任务又放弃, 重接时计数从 0 起。
        entity.set_stat(entity_id, "quest_" .. QUEST_ID .. "_kills", 0)
        if log and log.info then
            log.info("quest 10002: started entity_id=" .. tostring(entity_id))
        end
    end,

    on_complete = function(entity_id)
        local gw = entity.get_gateway_id(entity_id)
        if not gw then return end

        -- 奖励发放 — 走 entropy v1 path: random_attr_helper 会生成 4 槽
        -- common-tier 随机属性 (玩家职业 + race-aware), 第一件装备就有熵。
        local class_name = "default"
        if class_names and class_names.of_entity then
            class_name = class_names.of_entity(entity_id)
        end
        local race = entity.get_stat(entity_id, "faction") or 0

        if entropy and entropy.add_item_with_random_attr then
            entropy.add_item_with_random_attr(
                gw, REWARD_WEAPON_ID, 1,
                class_name, "common", race, season_seed and season_seed() or 0)
        else
            -- 非常理论上的 fallback: entropy 模块没加载也不能让任务卡死
            player.add_item(gw, REWARD_WEAPON_ID, 1)
        end

        -- EXP 奖励: 直接走 player.add_exp (与 on_kill.lua 同 API, 不重写)
        if player.add_exp then
            player.add_exp(gw, REWARD_EXP)
        end

        -- 清掉 kill_count, 防止下次同任务残留 (quest 框架 state=0, 但 kills 是
        -- 我们额外存的 stat, 框架不知道)。
        entity.set_stat(entity_id, "quest_" .. QUEST_ID .. "_kills", 0)

        if log and log.info then
            log.info("quest 10002: rewards granted entity_id=" .. tostring(entity_id)
                .. " weapon=" .. tostring(REWARD_WEAPON_ID)
                .. " exp=" .. tostring(REWARD_EXP))
        end
    end,
})

-- ----------------------------------------------------------------------------
-- 击杀进度 hook
-- ----------------------------------------------------------------------------
-- 不修改 events/on_kill.lua (它是中央死亡 dispatcher, 改动风险大), 改用
-- 包装模式: 拿到原 on_entity_killed 引用, 包一层先调原函数, 再做任务推进。
-- 这样 A8 也可以独立 wrap 同一函数 (loot pipeline), 顺序无关 (quest 推进
-- 与 loot 派发互不依赖, 都基于"victim 已死"事实)。
do
    local orig = on_entity_killed
    on_entity_killed = function(killer_id, victim_id)
        -- 关键: 在 orig 跑之前先快照 victim 的 NPC template, 因为 orig 会
        -- 调用 world.despawn(victim) 把 NpcComp 移走, 之后 get_npc_template
        -- 永远返回 0, quest hook 拿不到目标 mob 信息。
        local victim_tmpl = entity.get_npc_template
            and entity.get_npc_template(victim_id) or 0

        -- 1) 跑原死亡逻辑 (broadcast / EXP / despawn)
        if orig then orig(killer_id, victim_id) end

        -- 2) quest 进度: 仅当 killer 是玩家 + victim 是目标 mob 时计数。
        local killer_gw = entity.get_gateway_id(killer_id)
        if not killer_gw then return end
        if victim_tmpl ~= TARGET_MOB then return end

        if quest.state(killer_id, QUEST_ID) <= 0 then return end  -- 未接任务

        local key = "quest_" .. QUEST_ID .. "_kills"
        local cur = entity.get_stat(killer_id, key) or 0
        cur = cur + 1
        entity.set_stat(killer_id, key, cur)

        if cur >= KILLS_NEEDED then
            -- 进 ready-to-turn-in (state=99 沿用 lib/quest.lua 注释约定)
            quest.advance(killer_id, QUEST_ID, 99)
            if chat and chat.send_system then
                chat.send_system(killer_gw,
                    "Wisp in the Glade: target reached. Return to Scout Aldis.")
            end
        else
            if chat and chat.send_system then
                chat.send_system(killer_gw,
                    "Wisp slain (" .. tostring(cur) .. "/"
                    .. tostring(KILLS_NEEDED) .. ").")
            end
        end
    end
end
