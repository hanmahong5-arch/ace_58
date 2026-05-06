-- ClickHouse schema for AionCore log pipeline.
--
-- 该表是 logd 服务的唯一落盘对象。所有 5 个进程
-- (gateway/world/chat/logd/admin) 都通过 NATS subject log.<service>
-- 把 slog 记录推过来，logd 批量 Insert 到这里。
--
-- attrs 用 String 而不是 JSON 类型：跨 ClickHouse 版本兼容更稳，
-- 22.x → 24.x 之间 JSON column 实现来回改过几次；
-- 我们查询频率不高、字段固定，String + JSONExtractString() 足够。
--
-- 分区按月、ORDER BY (service, level, ts) 是 read pattern 决定：
-- 95% 的查询是 "某 service 在某时间段的 ERROR/WARN" → 这个序列让
-- 跳过 part 的力度最大。
--
-- TTL 30 天：超过的自动 drop。私服规模无需历史日志合规留存。

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
