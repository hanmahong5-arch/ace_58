-- scripts/npcs/npc_798010.lua
-- Round 11 B8 — content seed: dialog NPC "Verteron Scout Aldis".
--
-- 起始村庄 quest-giver。功能:
--   1. 寒暄 (option 0)
--   2. 接 quest 10002 "Wisp in the Glade" — 杀 3 只 Forest Wisp (215001)
--      并带回 1 个 Wispy Essence (掉落物，由 loot table 提供)
--   3. 完成时归还任务 (走 quest.complete -> on_complete callback)
--
-- 设计:
--   * quest gating 用 quest.state(eid, qid) 检查，避免重复接 / 重复完成。
--   * 完成时验收"是否带 3 击杀+1 掉落"放在 on_complete callback (quest_10002)
--     侧；NPC 这里只是 UI 入口。
--   * 模板 ID 798010 延续 798xxx Sanctum NPC 命名段，但语境是 Verteron
--     起始村 (实际地理位置由 spawn data 决定，与脚本无关)。

local QUEST_ID  = 10002
local OPT_EXIT  = 0
local OPT_ACCEPT = 1
local OPT_TURNIN = 2

dialog.register(798010, function(ctx, npc_eid, option_id)
    local gw  = ctx.gateway_seq_id
    local eid = ctx.entity_id

    -- 共享: 当前任务进度，用来决定显示"接任务"/"交任务"/"已完成"。
    local q_state = quest.state(eid, QUEST_ID)

    if option_id == 0 then
        -- 初始打开: 根据 quest 状态显示不同选项集。
        local options = {}
        if q_state == 0 then
            -- 还没接 → 显示"接受"
            table.insert(options, { id = OPT_ACCEPT, text = "I will help. (Accept quest)" })
        elseif q_state == 99 then
            -- ready to turn in → 显示"交任务"
            table.insert(options, { id = OPT_TURNIN, text = "I have slain the wisps. (Complete)" })
        else
            -- 进行中 → 只能寒暄
            table.insert(options, { id = OPT_EXIT,   text = "(Quest in progress — return when finished.)" })
        end
        table.insert(options, { id = OPT_EXIT, text = "Farewell." })

        dialog.send_window(gw, npc_eid,
            "Scout Aldis",
            "Daeva, those wisps in the glade trouble our outpost. "
            .. "Could I trouble you to thin their numbers?",
            options)
        return
    end

    if option_id == OPT_ACCEPT and q_state == 0 then
        -- 启动任务。quest.start 内部 set_stat quest_10002_state=1 + 触发 on_start。
        local ok = quest.start(eid, QUEST_ID)
        if ok then
            chat.send_system(gw,
                "Quest accepted: Wisp in the Glade. Slay 3 Forest Wisps.")
        else
            chat.send_system(gw, "Cannot accept quest at this time.")
        end
        return
    end

    if option_id == OPT_TURNIN and q_state == 99 then
        -- 完成任务。quest.complete 触发 on_complete callback (quest_10002.lua)，
        -- 在那里发奖励 (entropy.add_item_with_random_attr) + EXP。
        quest.complete(eid, QUEST_ID)
        chat.send_system(gw, "Quest complete! Take this reward — well earned.")
        return
    end

    -- 其余 (含 OPT_EXIT 与状态不匹配的 click): 静默关闭
end)
