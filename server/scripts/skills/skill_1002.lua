-- scripts/skills/skill_1002.lua
-- Round 11 B8 — content seed: skill "Quick Slash".
--
-- Universal melee 攻击技能 (任何职业均可在内容种子阶段释放), 用于:
--   1. 玩家攻击 mob_215001 触发 combat.deal_damage → on_entity_killed
--      → loot pipeline。
--   2. mob_215001 react_skill_id 字段引用本技能, 让怪物反击玩家
--      (反击 hook 留给后续 patch wired in cm_attack.lua)。
--
-- 与 skill_1001 (Fierce Strike) 区别:
--   * 倍率 1.0 而非 1.5 (新手攻击, 不应过强)
--   * cooldown 2s 而非 8s (允许新手快速连击节奏)
--   * mp_cost 0 (新手无 MP 概念, 避免被卡在没 MP 的尴尬)
--   * range 5.0 m (略小于标准 6, 鼓励近身)
--
-- 设计参考: skill_1001 的伤害公式 + 命中 + crit 模型, 复用相同模式以保持
-- 战斗手感一致 (玩家学一次就能预测所有 melee 攻击)。

skill.register({
    id       = 1002,
    name     = "Quick Slash",
    cooldown = 2,    -- 2-second cooldown (鼓励新手快速攻击节奏)
    mp_cost  = 0,    -- 0 MP (starter friendly)
    range    = 5.0,  -- metres (略小于标准 melee 6m)

    on_use = function(ctx, target_id)
        if not target_id or target_id == 0 then return end

        -- 1) 距离校验 — 不在 5m 内直接 silent return (skill 框架已扣 cd, 这是
        --    玩家自己点错的代价, 不必发提示)。
        local nearby = entity.get_nearby(ctx.entity_id, 5.0)
        local in_range = false
        for _, nid in ipairs(nearby) do
            if nid == target_id then in_range = true; break end
        end
        if not in_range then return end

        -- 2) 命中: 与 skill_1001 同公式 (90% baseline + level diff × 2pp)
        local atk_lvl = math.max(1, entity.get_stat(ctx.entity_id, "level"))
        local def_lvl = math.max(1, entity.get_stat(target_id, "level"))
        local hit_chance = math.min(0.95, math.max(0.10,
            0.90 + (atk_lvl - def_lvl) * 0.02))
        if math.random() > hit_chance then return end

        -- 3) 伤害: base 10 + level × 5 (1.0× — 比 skill_1001 弱 1/3)
        local base_dmg  = 10 + atk_lvl * 5
        local lv_factor = math.max(0.5, math.min(1.5,
            1.0 + (def_lvl - atk_lvl) * 0.05))
        local damage    = math.floor(base_dmg * lv_factor)
        local is_crit   = math.random() < 0.10
        if is_crit then damage = math.floor(damage * 2.0) end

        local remaining = combat.deal_damage(ctx.entity_id, target_id, damage, "physical")

        -- 4) SM_SKILL_RESULT 广播 (与 1001 同 opcode 0x5E + payload 格式)
        local buf = bytes.new()
        buf:write_int32(ctx.entity_id)
        buf:write_int32(1002)
        buf:write_int32(target_id)
        buf:write_int32(damage)
        buf:write_int32(math.floor(remaining))
        buf:write_byte(is_crit and 1 or 0)
        local pkt = buf:to_string()

        local obs = entity.get_nearby(ctx.entity_id, 200.0)
        for _, nid in ipairs(obs) do
            local gw = entity.get_gateway_id(nid)
            if gw then player.send_packet(gw, 0x5E, pkt) end
        end

        if log and log.info then
            log.info("skill_1002: entity=" .. tostring(ctx.entity_id)
                .. " target=" .. tostring(target_id)
                .. " dmg=" .. tostring(damage)
                .. (is_crit and " CRIT" or ""))
        end

        -- 5) 死亡 → 走全局 on_entity_killed (events/on_kill.lua), 在那里:
        --    a. broadcast SM_DIE
        --    b. 触发 EXP/level-up
        --    c. (A8) lib/loot.lua 监听 on_kill 派发掉落
        if remaining <= 0 then
            if on_entity_killed then
                on_entity_killed(ctx.entity_id, target_id)
            else
                -- Fallback (启动期 on_kill 未加载)
                local gw2 = entity.get_gateway_id(target_id)
                if not gw2 then world.despawn(target_id)
                else entity.set_stat(target_id, "dead", 1) end
            end
        end
    end,
})
