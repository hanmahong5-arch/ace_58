-- scripts/instances/inst_300040000_haramel.lua
-- Haramel Training Grounds (solo tutorial cave, lv1-10).
--
-- Based on NCSoft's original Haramel instance WorldID 300040000. Used as the
-- canonical solo-instance demo for Phase S-19. The spawn/boss coordinates are
-- synthetic (MVP) — refine when the real Aion-pak extracted spawn data lands
-- in scripts/data/. Rewards are tuned for the low-level training loop:
-- 5 000 kinah + 1 × "warrior starter weapon" (item id 110000001 placeholder).

instance.register({
    template_id     = 300040000,
    display_name    = "Haramel Training Grounds",
    world_id        = 300040000,

    min_level       = 1,
    max_level       = 10,
    min_members     = 1,
    max_members     = 1,             -- solo

    reentrance_sec  = 3600 * 4,      -- 4h cooldown
    validity_hours  = 2,             -- auto-expire after 2h live
    reset_fee_kinah = 1000,

    -- Spawn + boss coordinates (in-world). Boss ~40m northeast of spawn
    -- so the player can hit it with ranged attacks from a safe distance.
    spawn_x = 1024.0, spawn_y = 1024.0, spawn_z = 300.0,
    boss_template = 215001,  -- placeholder NPC template id
    boss_x = 1060.0, boss_y = 1060.0, boss_z = 300.0,

    rewards = {
        kinah = 5000,
        -- Round 11 A8 (patch 02): 标注 reward 元数据。
        -- Haramel 是 lv1-10 训练副本, armor 入门级 — common tier (3 manastone,
        -- affix=false 不进 v1)。新人感受"这是我第一件本掉防具"已足够 wow。
        items = { { id = 110000001, count = 1, class = "armor", tier = "common", affix = false } },
    },
})
