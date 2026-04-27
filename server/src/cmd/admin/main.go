// Package main is the entry point for the Admin API service.
// REST API + Web dashboard for GM operations, player management,
// server monitoring. Replaces NCSoft's ASP.NET GM tool.
//
// Sprint 0 / Round-10 boot-up note:
// admin REST 端点未实现（known-gaps #5）。本 main 暂仅负责 boot 不 panic
// 并阻塞等待 SIGINT/SIGTERM，使 5 进程拓扑健康检查通过。
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

	slog.Info("admin: stub running (REST API not implemented) — sleeping until signal")

	// 阻塞直到外部发出 SIGINT/SIGTERM。
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch

	slog.Info("admin: shutting down")
}
