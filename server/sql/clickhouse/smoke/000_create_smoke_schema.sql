-- ClickHouse smoke schema — 冒烟测试专用初始化脚本。
--
-- 与 sql/clickhouse/001_log_events.sql 关系
-- ------------------------------------------
-- 001_log_events.sql 是生产 schema，落在 default 数据库（生产 logd 直连
-- clickhouse://default@host/aion，aion 库由 dev 蓝图另行创建）。
--
-- 冒烟环境为隔离起见落在 aion_test 库（通过 CLICKHOUSE_DB env 自动建库），
-- 但表结构必须与生产 byte-for-byte 一致——任何字段漂移意味着冒烟 PASS
-- 不能代表生产能用，价值瞬间归零。
--
-- 因此本文件复制了 001_log_events.sql 的 CREATE TABLE 内容，仅前缀一句
-- USE aion_test。维护约定：
--
--    001_log_events.sql 改字段 → 本文件必须同步改字段。
--
-- 这是有意为之的"双写"——隔离收益 > 同步成本。CI 加一条 diff guard
-- 即可强制保持同步（见 doc/observability.md "已知限制"段补充）。

-- ClickHouse Docker 镜像在 init 时把 CLICKHOUSE_DB env 指定的库自动建好；
-- 这里只需切换 + 建表。如果有人手动跑（不走 docker），需先 CREATE DATABASE。
CREATE DATABASE IF NOT EXISTS aion_test;

USE aion_test;

CREATE TABLE IF NOT EXISTS log_events (
    ts       DateTime64(3),
    service  LowCardinality(String),
    level    LowCardinality(String),
    msg      String,
    attrs    String  -- JSON-encoded; query via JSONExtract*
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (service, level, ts)
TTL toDateTime(ts) + INTERVAL 30 DAY
SETTINGS index_granularity = 8192;
