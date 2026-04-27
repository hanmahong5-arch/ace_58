// Package main is the entry point for the Log Pipeline service.
// Receives structured log events from all services via NATS,
// batches them, and writes to ClickHouse for analytics.
//
// Sprint 0 / Round-10 boot-up note:
// logd 在 ClickHouse pipeline 接通之前是占位实现。本 main 函数仅负责 boot
// 不 panic 并阻塞等待 SIGINT/SIGTERM，便于 5 进程拓扑健康检查通过。
package main

import (
	"log/slog"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	// 结构化日志 — 与 gateway/world 保持同款 JSON 输出。
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))

	slog.Info("logd: stub running (ClickHouse pipeline not implemented) — sleeping until signal")

	// 阻塞直到外部发出 SIGINT/SIGTERM。
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch

	slog.Info("logd: shutting down")
}
