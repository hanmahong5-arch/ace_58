-- AionCore 5.8 — user_item_option randomValue1..10 schema-level防御 CHECK constraints.
--
-- STORY-1 (BMAD Phase 4 Sprint 0) — closes spike WARN-1 (2026-05-06)
--
-- 背景:
--   2026-05-06 cmd/spike --edge random_attr-extreme-x1.20 step
--   `pg.user_item_option.randomValue_extremes` 报 🟡 WARN:
--     "PG 接受极值 (含越 NCSoft max 的 120 + INT32 上限) 而无校验;
--      真客户端读到 randomValue=120 (实证 max=65 的 magicalSkillBoost) 行为未定义。"
--
--   Lua 层 (scripts/entropy/random_attr_helper.lua §5) 已 clamp，但只是第一道防线。
--   GM 工具直注 / spsynth-generated SP / 第三方运营脚本可绕过 Lua 写入越界值。
--   本 migration 在 schema 层加 defense-in-depth.
--
-- 范围选择 [-345, 245]:
--   23 NCSoft 实证 attr_id (random_attr_helper.lua §1) 全集:
--     min: maxHp=-347, dodge=-53, parry=-98, block=-145, ...
--     max: maxMp=245, parry=107, block=119, ...
--   选 [-345, 245] (留 2 缓冲防 Lua round 误差)。
--   单 attr 精确范围由 Lua 层保证，本 CHECK 是粗粒度兜底。
--
-- 10 列独立 constraint vs 1 个复合 constraint:
--   选 10 个独立 — PG 违反 CHECK 时错误信息含 constraint 名，直接定位 slot N。
--   写法稍长但运维诊断成本下降一个数量级。

-- +goose Up
-- +goose StatementBegin

ALTER TABLE user_item_option
    ADD CONSTRAINT user_item_option_randomvalue1_check  CHECK (randomValue1  IS NULL OR randomValue1  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue2_check  CHECK (randomValue2  IS NULL OR randomValue2  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue3_check  CHECK (randomValue3  IS NULL OR randomValue3  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue4_check  CHECK (randomValue4  IS NULL OR randomValue4  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue5_check  CHECK (randomValue5  IS NULL OR randomValue5  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue6_check  CHECK (randomValue6  IS NULL OR randomValue6  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue7_check  CHECK (randomValue7  IS NULL OR randomValue7  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue8_check  CHECK (randomValue8  IS NULL OR randomValue8  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue9_check  CHECK (randomValue9  IS NULL OR randomValue9  BETWEEN -345 AND 245),
    ADD CONSTRAINT user_item_option_randomvalue10_check CHECK (randomValue10 IS NULL OR randomValue10 BETWEEN -345 AND 245);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

ALTER TABLE user_item_option
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue10_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue9_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue8_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue7_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue6_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue5_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue4_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue3_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue2_check,
    DROP CONSTRAINT IF EXISTS user_item_option_randomvalue1_check;

-- +goose StatementEnd
