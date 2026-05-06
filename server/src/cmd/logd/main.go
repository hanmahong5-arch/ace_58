// Package main is the entry point for the AionCore Log Pipeline service (logd).
//
// 拓扑（详见 server/CLAUDE.md）：
//
//	5 进程都用 telemetry.NATSHandler 把 slog 记录推到 subject log.<service>。
//	logd 起 JetStream durable consumer 订阅 log.>，攒到 1000 条或 5s 就批量
//	Insert 到 ClickHouse log_events 表。
//
// 为什么 ClickHouse 而不是 Loki / Elasticsearch / OTel collector？
//
//	评估了 4 个候选：
//	  - Loki：标签压缩好、但全文搜索弱、Grafana 强绑定；
//	  - ES：搜索强、但 JVM 吃内存、单节点 ≥4G、对小私服过重；
//	  - OTel collector + 其中之一：异构语言栈才需要的中间层，单 Go 栈纯增加运维面；
//	  - ClickHouse：Insert 吞吐 200K rows/s 起步、SQL 直接查、单节点 1G 够跑、
//	    AionCore 已有 v2 driver 锚定 → 决策是它。
//
//	如果以后接入 BEY_4.8 Java 或 ai-system Python，再上 OTel collector 也不迟。
//
// 配置（环境变量）：
//
//	NATS_URL         默认 nats://127.0.0.1:4222
//	CLICKHOUSE_DSN   默认 clickhouse://default@127.0.0.1:9000/aion
//	LOGD_BATCH_ROWS  默认 1000
//	LOGD_BATCH_AGE   默认 5s（time.ParseDuration）
//	LOGD_DURABLE     默认 logd-main（同集群多实例需改）
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
)

// 默认配置——所有可调项都给环境变量逃生口。
const (
	defaultNATSURL       = "nats://127.0.0.1:4222"
	defaultClickHouseDSN = "clickhouse://default@127.0.0.1:9000/aion"
	defaultBatchRows     = 1000
	defaultBatchAge      = 5 * time.Second
	defaultDurable       = "logd-main"

	streamName  = "LOGS"
	subjectGlob = "log.>"
)

func main() {
	// stdout JSON——logd 自己的运行日志走标准 slog（不能用 NATSHandler，
	// 否则它要给自己发消息，鸡生蛋）。
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))

	if err := run(); err != nil {
		slog.Error("logd: fatal", "err", err)
		os.Exit(1)
	}
}

func run() error {
	natsURL := envOrDefault("NATS_URL", defaultNATSURL)
	chDSN := envOrDefault("CLICKHOUSE_DSN", defaultClickHouseDSN)
	durable := envOrDefault("LOGD_DURABLE", defaultDurable)
	batchRows := envIntOrDefault("LOGD_BATCH_ROWS", defaultBatchRows)
	batchAge := envDurationOrDefault("LOGD_BATCH_AGE", defaultBatchAge)

	rootCtx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	// 1) ClickHouse —— 起得起来才有意义订阅，先连这个。
	connCtx, connCancel := context.WithTimeout(rootCtx, 10*time.Second)
	writer, err := newCHWriter(connCtx, chDSN)
	connCancel()
	if err != nil {
		return fmt.Errorf("clickhouse: %w", err)
	}
	slog.Info("logd: clickhouse connected", "dsn", redactDSN(chDSN))

	b := newBatcher(writer, batchRows, batchAge)

	// 2) NATS + JetStream 订阅 log.>
	nc, err := nats.Connect(natsURL,
		nats.MaxReconnects(-1),                    // logd 必须长时间在线，无限重连
		nats.ReconnectWait(2*time.Second),
		nats.DisconnectErrHandler(func(_ *nats.Conn, e error) {
			slog.Warn("logd: nats disconnected", "err", e)
		}),
		nats.ReconnectHandler(func(c *nats.Conn) {
			slog.Info("logd: nats reconnected", "url", c.ConnectedUrl())
		}),
	)
	if err != nil {
		_ = b.close(context.Background())
		return fmt.Errorf("nats connect: %w", err)
	}
	defer nc.Close()
	slog.Info("logd: nats connected", "url", natsURL)

	js, err := jetstream.New(nc)
	if err != nil {
		_ = b.close(context.Background())
		return fmt.Errorf("jetstream new: %w", err)
	}

	if err := ensureStream(rootCtx, js); err != nil {
		_ = b.close(context.Background())
		return fmt.Errorf("ensure stream: %w", err)
	}

	cons, err := js.CreateOrUpdateConsumer(rootCtx, streamName, jetstream.ConsumerConfig{
		Durable:       durable,
		AckPolicy:     jetstream.AckExplicitPolicy,
		DeliverPolicy: jetstream.DeliverNewPolicy, // logd 不关心历史，重启后从新消息开始
		FilterSubject: subjectGlob,
		MaxAckPending: batchRows * 2, // 给 batcher 一倍空间，避免 NATS 早早回压
	})
	if err != nil {
		_ = b.close(context.Background())
		return fmt.Errorf("create consumer: %w", err)
	}
	slog.Info("logd: jetstream consumer ready", "stream", streamName, "durable", durable)

	consumeCtx, err := cons.Consume(func(msg jetstream.Msg) {
		var rec logRecord
		if err := json.Unmarshal(msg.Data(), &rec); err != nil {
			slog.Warn("logd: bad json record, dropping", "err", err)
			_ = msg.Term() // 永久丢弃这条——重传也会失败
			return
		}
		service := serviceFromSubject(msg.Subject())
		if err := b.add(rootCtx, rec, service); err != nil {
			slog.Error("logd: batcher add", "err", err)
			_ = msg.Nak() // 让 NATS 重投
			return
		}
		_ = msg.Ack()
	})
	if err != nil {
		_ = b.close(context.Background())
		return fmt.Errorf("consume: %w", err)
	}
	defer consumeCtx.Stop()

	// 3) Ticker —— 周期性触发 batch.tick，覆盖"流量稀疏但 batch 不空"的场景。
	go runTicker(rootCtx, b, batchAge)

	// 4) 等信号，优雅 shutdown。
	<-rootCtx.Done()
	slog.Info("logd: shutdown signal received, flushing")

	// 给 flush 留 10s 上限——超时也要走完关连接逻辑。
	flushCtx, flushCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer flushCancel()
	if err := b.close(flushCtx); err != nil {
		slog.Error("logd: final flush", "err", err)
	}
	slog.Info("logd: shutdown complete")
	return nil
}

// runTicker 周期 tick batcher。由 maxAge / 2 决定 tick 频率——保证
// 最坏 1.5 × maxAge 内一定 flush，又不至于空跑太频繁。
func runTicker(ctx context.Context, b *batcher, maxAge time.Duration) {
	interval := maxAge / 2
	if interval < 100*time.Millisecond {
		interval = 100 * time.Millisecond
	}
	t := time.NewTicker(interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if err := b.tick(ctx); err != nil {
				slog.Error("logd: ticker tick", "err", err)
			}
		}
	}
}

// ensureStream 确保 LOGS stream 存在。已存在则 noop（CreateStream 会报
// stream name already in use；用 Update 兜底使配置可演进）。
func ensureStream(ctx context.Context, js jetstream.JetStream) error {
	cfg := jetstream.StreamConfig{
		Name:      streamName,
		Subjects:  []string{subjectGlob},
		Retention: jetstream.LimitsPolicy,
		MaxAge:    1 * time.Hour,
		MaxBytes:  512 * 1024 * 1024, // 512 MB 兜底
		Storage:   jetstream.FileStorage,
		Discard:   jetstream.DiscardOld,
	}
	_, err := js.CreateStream(ctx, cfg)
	if err == nil {
		slog.Info("logd: stream created", "name", streamName)
		return nil
	}
	if errors.Is(err, jetstream.ErrStreamNameAlreadyInUse) {
		// 已存在 → Update 把配置对齐到当前版本期望
		if _, uerr := js.UpdateStream(ctx, cfg); uerr != nil {
			return fmt.Errorf("update existing stream: %w", uerr)
		}
		slog.Info("logd: stream updated", "name", streamName)
		return nil
	}
	return err
}

// serviceFromSubject: "log.gateway" → "gateway"; "log.world.session" → "world.session"
func serviceFromSubject(subj string) string {
	const prefix = "log."
	if strings.HasPrefix(subj, prefix) {
		return subj[len(prefix):]
	}
	return subj
}

// redactDSN 把密码部分挖掉再打日志。clickhouse:// 与 tcp:// 两种格式都覆盖。
func redactDSN(dsn string) string {
	at := strings.LastIndex(dsn, "@")
	scheme := strings.Index(dsn, "://")
	if at < 0 || scheme < 0 || at <= scheme+3 {
		return dsn
	}
	return dsn[:scheme+3] + "***@" + dsn[at+1:]
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envIntOrDefault(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return def
}

func envDurationOrDefault(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil && d > 0 {
			return d
		}
	}
	return def
}
