// Package main is the entry point for the Chat Service.
// Handles channel chat, whispers, group chat, and HMAC authentication.
// Designed for independent horizontal scaling (target: 100k concurrent).
//
// Sprint 0 / Round-10 boot-up note:
// chat 服务在 Phase S-3 之前是占位实现。本 main 函数仅负责 boot 不 panic
// 并阻塞等待 SIGINT/SIGTERM，使得"5 进程拓扑健康检查"可以观察到 chat 进程
// 长期存活，而不会立刻退出导致 process supervisor / Makefile 误判失败。
package main

import (
	"log/slog"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	// 结构化日志 — 与其他服务（gateway/world）保持一致的 JSON 格式，
	// 便于将来 logd 服务统一抓取。
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))

	slog.Info("chat: stub running (Phase S-3 not implemented) — sleeping until signal")

	// 阻塞直到外部发出 SIGINT/SIGTERM。零业务逻辑、零端口监听、零依赖。
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch

	slog.Info("chat: shutting down")
}
