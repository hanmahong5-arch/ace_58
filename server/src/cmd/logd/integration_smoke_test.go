//go:build integration
// +build integration

// logd ↔ ClickHouse 端到端冒烟（生产前必跑）。
//
// 为什么需要这个文件
// ------------------
// R5 swarm 把 logd 的 batcher / writer 接口拆得很干净，单测里 fakeWriter
// 把"5s 或 1000 行"这套 batch 触发逻辑覆盖得严严实实。但 ClickHouse v2
// driver 的真实行为（DSN parse、Ping、PrepareBatch、Send、LowCardinality
// 字段、JSON 字符串 attrs 入库）一行都没碰过——一旦上线某个版本的
// clickhouse-go 把 PrepareBatch 的 SQL 行为悄悄改了，fakeWriter 不会发现。
//
// 这个测试是 R5 swarm 收尾时 doc/observability.md "部署前 smoke 清单"
// 332-342 行明确列的 4 步人工核查的"代码化版本"——任何想往生产推 logd
// 的人都必须先让这条 PASS。
//
// 运行约定
// --------
//
//	# 一键起容器（单独一个 compose 文件，与生产 docker-compose.dev.yml 互不影响）
//	docker compose -f deploy/docker-compose.clickhouse-smoke.yml up -d
//
//	# 跑测试
//	cd src
//	CLICKHOUSE_DSN_TEST=clickhouse://default:@127.0.0.1:9000/aion_test \
//	NATS_URL_TEST=nats://127.0.0.1:14222 \
//	  go test -tags=integration -v ./cmd/logd/... -run TestSmoke -count=1
//
//	# 收尾
//	docker compose -f deploy/docker-compose.clickhouse-smoke.yml down -v
//
// 任一环境变量缺失即 t.Skip()，CI 默认 `go test ./...` 不会因此 fail。
//
// 与既有约定的对齐
// ----------------
//
//   - build tag `integration` 与 internal/database/integration_test.go 同款；
//   - "缺 env 跳过" 模式与 internal/ipc/nats_smoke_test.go (build tag `nats`) 同款；
//   - DSN 默认值与 deploy/docker-compose.clickhouse-smoke.yml 暴露端口对齐。
//
// 这里有意保留两个独立环境变量名 CLICKHOUSE_DSN_TEST / NATS_URL_TEST，
// 不复用生产 CLICKHOUSE_DSN / NATS_URL：避免 dev 跑冒烟时把记录写进开发者
// 平时挂着的 ClickHouse 库里，污染本地数据。

package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
)

// 默认地址：与 deploy/docker-compose.clickhouse-smoke.yml 对齐。
// 生产 dev 环境的 NATS 走 4222，所以冒烟刻意挑 14222 错开。
const (
	smokeDSNDefault     = "clickhouse://default:@127.0.0.1:9000/aion_test"
	smokeNATSDefault    = "nats://127.0.0.1:14222"
	smokeDSNEnv         = "CLICKHOUSE_DSN_TEST"
	smokeNATSEnv        = "NATS_URL_TEST"
	smokeStreamName     = "LOGS_SMOKE"  // 与生产 LOGS stream 不同，避免共用 durable 状态
	smokeSubjectPrefix  = "log.smoke"   // 都进 log.smoke.<service>
	smokeWaitTimeout    = 30 * time.Second
)

// smokeEnv 拉两个环境变量；若任一空 → 调用方 t.Skip。
func smokeEnv(t *testing.T) (chDSN, natsURL string) {
	t.Helper()
	chDSN = os.Getenv(smokeDSNEnv)
	natsURL = os.Getenv(smokeNATSEnv)
	if chDSN == "" || natsURL == "" {
		t.Skipf("smoke skipped: set %s and %s; "+
			"see deploy/docker-compose.clickhouse-smoke.yml for one-line bring-up",
			smokeDSNEnv, smokeNATSEnv)
	}
	return chDSN, natsURL
}

// dialClickHouse 拨号 + Ping + truncate `log_events` 表（每个测试干净起跑）。
// 容器首启时已经从 /docker-entrypoint-initdb.d 跑过 001_log_events.sql 建表，
// 这里只是把上一轮残留行清掉。
func dialClickHouse(t *testing.T, ctx context.Context, dsn string) driver.Conn {
	t.Helper()
	opts, err := clickhouse.ParseDSN(dsn)
	if err != nil {
		t.Fatalf("parse clickhouse DSN %q: %v", dsn, err)
	}
	conn, err := clickhouse.Open(opts)
	if err != nil {
		t.Fatalf("open clickhouse: %v", err)
	}
	if err := conn.Ping(ctx); err != nil {
		_ = conn.Close()
		t.Skipf("clickhouse not reachable at %s: %v", dsn, err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	if err := conn.Exec(ctx, "TRUNCATE TABLE log_events"); err != nil {
		t.Fatalf("truncate log_events: %v", err)
	}
	return conn
}

// connectNATS 起一个允许快速失败的 NATS 客户端。
// MaxReconnects=0 + Timeout=1s 让"容器没起"的情况立刻 Skip 而不是干等。
func connectNATS(t *testing.T, url string) *nats.Conn {
	t.Helper()
	nc, err := nats.Connect(url,
		nats.Timeout(1*time.Second),
		nats.MaxReconnects(0),
	)
	if err != nil {
		t.Skipf("nats not reachable at %s: %v", url, err)
	}
	t.Cleanup(nc.Close)
	return nc
}

// publisherFromConn 把 *nats.Conn 包装成 `cmd/logd` 内部的 Publisher 抽象——
// 但本地 logd 用的是 NATSHandler 打包的 publisher；冒烟里我们直接 Publish JSON 行。
//
// 用 jetstream.JetStream 的 Publish（不是 core NATS）：logd 订阅的是
// jetstream consumer，必须经 stream 落地，不然 ack 链路对不上。
func ensureSmokeStream(t *testing.T, ctx context.Context, js jetstream.JetStream) {
	t.Helper()
	subjects := []string{smokeSubjectPrefix + ".>"}
	cfg := jetstream.StreamConfig{
		Name:      smokeStreamName,
		Subjects:  subjects,
		Retention: jetstream.LimitsPolicy,
		MaxAge:    10 * time.Minute,
		MaxBytes:  64 * 1024 * 1024,
		Storage:   jetstream.MemoryStorage, // 冒烟不需要持久化；容器删了就清
		Discard:   jetstream.DiscardOld,
	}
	if _, err := js.CreateStream(ctx, cfg); err != nil {
		if !errors.Is(err, jetstream.ErrStreamNameAlreadyInUse) {
			t.Fatalf("create smoke stream: %v", err)
		}
		if _, err := js.UpdateStream(ctx, cfg); err != nil {
			t.Fatalf("update smoke stream: %v", err)
		}
	}
	t.Cleanup(func() {
		bg, c := context.WithTimeout(context.Background(), 5*time.Second)
		defer c()
		_ = js.DeleteStream(bg, smokeStreamName)
	})
}

// publishRecords 经 JetStream 同步发 N 条 fake slog 记录到 log.smoke.<service>。
// 同步发是为了让"已发 N 条"有明确边界——异步 Publish 在 batcher 做断言时会含糊。
func publishRecords(t *testing.T, ctx context.Context, js jetstream.JetStream, service string, n int) {
	t.Helper()
	for i := 0; i < n; i++ {
		rec := logRecord{
			TS:    time.Now().UTC().Format(time.RFC3339Nano),
			Level: "INFO",
			Msg:   fmt.Sprintf("smoke #%d", i),
			Attrs: json.RawMessage(fmt.Sprintf(`{"i":%d,"service":%q}`, i, service)),
		}
		data, err := json.Marshal(rec)
		if err != nil {
			t.Fatalf("marshal rec %d: %v", i, err)
		}
		if _, err := js.Publish(ctx, smokeSubjectPrefix+"."+service, data); err != nil {
			t.Fatalf("js publish %d: %v", i, err)
		}
	}
}

// runConsumer 起一个 logd 风格的 jetstream consumer，把每条消息 Unmarshal 后
// 喂给传入的 batcher。返回 stop func。
//
// 与 cmd/logd/main.go 主流程一致：ExplicitAck、Term-on-bad-json、Nak-on-error。
// 只是 stream/durable 名换成 smoke 专属。
func runConsumer(t *testing.T, ctx context.Context, js jetstream.JetStream, b *batcher) func() {
	t.Helper()
	cons, err := js.CreateOrUpdateConsumer(ctx, smokeStreamName, jetstream.ConsumerConfig{
		Durable:       "logd-smoke",
		AckPolicy:     jetstream.AckExplicitPolicy,
		DeliverPolicy: jetstream.DeliverNewPolicy,
		FilterSubject: smokeSubjectPrefix + ".>",
		MaxAckPending: 4096,
	})
	if err != nil {
		t.Fatalf("create smoke consumer: %v", err)
	}
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		var rec logRecord
		if err := json.Unmarshal(msg.Data(), &rec); err != nil {
			_ = msg.Term()
			return
		}
		// "log.smoke.<service>" → "smoke.<service>"，与 serviceFromSubject 一致。
		service := serviceFromSubject(msg.Subject())
		if err := b.add(ctx, rec, service); err != nil {
			_ = msg.Nak()
			return
		}
		_ = msg.Ack()
	})
	if err != nil {
		t.Fatalf("smoke consume: %v", err)
	}
	return func() { cc.Stop() }
}

// waitForRowCount 轮询 ClickHouse 直到 SELECT count() 达到 want 或超时。
// 用 expect.poll 风格的小 sleep 而不是 timeout - 单次 sleep：早达到早返回。
func waitForRowCount(t *testing.T, ctx context.Context, conn driver.Conn, want int, timeout time.Duration) int {
	t.Helper()
	deadline := time.Now().Add(timeout)
	var got uint64
	for {
		row := conn.QueryRow(ctx, "SELECT count() FROM log_events")
		if err := row.Scan(&got); err != nil && !strings.Contains(err.Error(), "no rows") {
			t.Fatalf("count query: %v", err)
		}
		if int(got) >= want {
			return int(got)
		}
		if time.Now().After(deadline) {
			t.Fatalf("timeout: want >=%d rows, got %d after %v", want, got, timeout)
		}
		time.Sleep(100 * time.Millisecond)
	}
}

// =============================================================================
// 三个冒烟测试：覆盖 doc/observability.md 332-342 列的核查点
// =============================================================================

// TestSmokeClickHouseRoundtrip
//
//	doc/observability.md 332-342:
//	 1. 容器起来，schema 跑过 → dialClickHouse Ping + TRUNCATE 隐式覆盖
//	 2. NATS 起来 → connectNATS 显式覆盖
//	 3. logd 跑起来 → 这里用真 chWriter + 真 batcher + 真 jetstream consumer 等价 logd
//	 4. 任一进程 slog.Info 后能 SELECT 增长 → 这就是本测试断言
func TestSmokeClickHouseRoundtrip(t *testing.T) {
	chDSN, natsURL := smokeEnv(t)

	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	conn := dialClickHouse(t, ctx, chDSN)

	writer, err := newCHWriter(ctx, chDSN)
	if err != nil {
		t.Fatalf("newCHWriter: %v", err)
	}
	t.Cleanup(func() { _ = writer.Close() })

	// 把 maxAge 设极长 (1h)，让 row-limit (5) 触发 flush。
	b := newBatcher(writer, 5, time.Hour)

	nc := connectNATS(t, natsURL)
	js, err := jetstream.New(nc)
	if err != nil {
		t.Fatalf("jetstream new: %v", err)
	}
	ensureSmokeStream(t, ctx, js)

	stop := runConsumer(t, ctx, js, b)
	defer stop()

	// 发 5 条 → batcher 立即 flush（等达到 row limit）。
	publishRecords(t, ctx, js, "round", 5)

	got := waitForRowCount(t, ctx, conn, 5, smokeWaitTimeout)
	t.Logf("roundtrip ok: %d rows visible in ClickHouse", got)

	// 顺便验 attrs JSON 没被吞——LowCardinality 字段 service / level 也接受多值。
	var (
		svc, level, attrs string
	)
	row := conn.QueryRow(ctx,
		`SELECT service, level, attrs FROM log_events
		 WHERE JSONExtractInt(attrs, 'i') = 0 LIMIT 1`)
	if err := row.Scan(&svc, &level, &attrs); err != nil {
		t.Fatalf("inspect first row: %v", err)
	}
	if svc != "smoke.round" {
		t.Errorf("service = %q, want %q (subject parse drift?)", svc, "smoke.round")
	}
	if level != "INFO" {
		t.Errorf("level = %q, want INFO", level)
	}
	if !strings.Contains(attrs, `"i":0`) {
		t.Errorf("attrs = %q, want JSON containing i:0", attrs)
	}
}

// TestSmokeBatchTimeFlush
//
//	验 maxAge 触发：发 3 条（远低于 row limit），等过 maxAge tick，
//	也能 flush 进 ClickHouse。
//
// 用极小 maxAge（800ms）+ 1500ms 等待，避免长测拖累 CI。
func TestSmokeBatchTimeFlush(t *testing.T) {
	chDSN, natsURL := smokeEnv(t)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn := dialClickHouse(t, ctx, chDSN)

	writer, err := newCHWriter(ctx, chDSN)
	if err != nil {
		t.Fatalf("newCHWriter: %v", err)
	}
	t.Cleanup(func() { _ = writer.Close() })

	const maxAge = 800 * time.Millisecond
	// row limit 给 1000——绝对触不到，把 flush 决策权全交给 ticker。
	b := newBatcher(writer, 1000, maxAge)

	nc := connectNATS(t, natsURL)
	js, err := jetstream.New(nc)
	if err != nil {
		t.Fatalf("jetstream new: %v", err)
	}
	ensureSmokeStream(t, ctx, js)

	stop := runConsumer(t, ctx, js, b)
	defer stop()

	// 模拟 main.go 的 ticker。频率 = maxAge/2，最坏 1.5×maxAge 内必 flush。
	tickerStop := make(chan struct{})
	defer close(tickerStop)
	go func() {
		t := time.NewTicker(maxAge / 2)
		defer t.Stop()
		for {
			select {
			case <-tickerStop:
				return
			case <-t.C:
				_ = b.tick(ctx)
			}
		}
	}()

	publishRecords(t, ctx, js, "tick", 3)

	got := waitForRowCount(t, ctx, conn, 3, 10*time.Second)
	if got < 3 {
		t.Fatalf("after maxAge tick: got %d rows, want 3", got)
	}
	t.Logf("time-flush ok: %d rows after %v ticker", got, maxAge)
}

// TestSmokeMultiServiceLowCardinality
//
//	发 5 个不同 service（gateway/world/chat/admin/logd），验
//	LowCardinality(service) 字段 + ORDER BY (service, level, ts) 正常。
//
// 这条特意检查 schema ORDER BY 的"多 service 字典编码"行为——
// 任何针对 schema 的 PR（改 PARTITION/ORDER BY/TTL）都该让这条还过。
func TestSmokeMultiServiceLowCardinality(t *testing.T) {
	chDSN, natsURL := smokeEnv(t)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	conn := dialClickHouse(t, ctx, chDSN)

	writer, err := newCHWriter(ctx, chDSN)
	if err != nil {
		t.Fatalf("newCHWriter: %v", err)
	}
	t.Cleanup(func() { _ = writer.Close() })
	b := newBatcher(writer, 5, time.Hour)

	nc := connectNATS(t, natsURL)
	js, err := jetstream.New(nc)
	if err != nil {
		t.Fatalf("jetstream new: %v", err)
	}
	ensureSmokeStream(t, ctx, js)

	stop := runConsumer(t, ctx, js, b)
	defer stop()

	services := []string{"gateway", "world", "chat", "admin", "logd"}
	for _, svc := range services {
		publishRecords(t, ctx, js, svc, 1)
	}

	_ = waitForRowCount(t, ctx, conn, 5, smokeWaitTimeout)

	// 每个 service 至少 1 行。
	rows, err := conn.Query(ctx,
		`SELECT service, count() FROM log_events GROUP BY service ORDER BY service`)
	if err != nil {
		t.Fatalf("group query: %v", err)
	}
	defer rows.Close()
	seen := make(map[string]uint64)
	for rows.Next() {
		var s string
		var n uint64
		if err := rows.Scan(&s, &n); err != nil {
			t.Fatalf("scan group: %v", err)
		}
		seen[s] = n
	}
	for _, svc := range services {
		want := "smoke." + svc
		if seen[want] < 1 {
			t.Errorf("service %q: got %d rows, want >=1", want, seen[want])
		}
	}
}

// 让 `go vet` 不抱怨 atomic 在某些组合下未引用。
var _ = atomic.Int64{}
