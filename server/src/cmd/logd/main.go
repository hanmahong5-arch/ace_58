// Package main is the entry point for the Log Pipeline service.
//
// 接收来自所有服务的 slog JSON 日志（NATS subject log.<service>）
// 批量写入 ClickHouse 用于分析（5s 或 1000 条 flush）。
//
// 当前阶段：deps 已锚定（clickhouse-go v2）。NATS Subscribe 与
// ClickHouse batch writer 由 W2 swarm 扩充。
//
// 设计要点：
//   - log.* subject 走 NATS JetStream，MaxAge=1h MaxBytes=512MB（兜底丢弃）
//   - slog Handler 端必须异步 chan+worker，否则同步 Publish 拖慢热路径
//   - ClickHouse schema 一次定准：
//       (ts DateTime64(3), service LowCardinality(String),
//        level LowCardinality(String), msg String, attrs JSON)
//   - 不在 Handler 里再调 slog（递归死循环）
package main

import (
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	_ "github.com/ClickHouse/clickhouse-go/v2" // anchored: used by batch writer (W2)
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))

	slog.Info("logd: deps anchored (clickhouse-go v2) — pipeline impl by W2")

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch

	slog.Info("logd: shutting down")
}
