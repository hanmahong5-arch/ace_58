# AionCore 5.8 — 单体仓库 Makefile
#
# 设计原则：
#   - 只做 dev/debug 构建（与全局 CLAUDE.md 约定一致）
#   - 不依赖 Docker、不依赖 release flag
#   - 中间件用 Go 自举的轻量替代（nats-server + devredis 单二进制）
#   - 任何 boot 失败应快速暴露，不要静默掩盖
#
# 常用目标：
#   make build          编译全部 5 进程到 ./bin/
#   make boot-test      启动中间件 + 5 进程 + 跑 tinyclient 端到端验证
#   make boot           仅启动中间件 + 5 进程（不跑 client）
#   make stop           停止 5 进程 + 中间件（不动 PostgreSQL 服务）
#   make clean          删除 bin/ 编译产物（保留 *.log）

SHELL          := /bin/bash
SERVER_ROOT    := $(CURDIR)
BIN_DIR        := $(SERVER_ROOT)/bin
SRC_DIR        := $(SERVER_ROOT)/src
CONFIG_DIR     := $(SERVER_ROOT)/config
LOG_DIR        := $(SERVER_ROOT)/logs
GOBIN          := $(shell go env GOPATH)/bin
NATS_BIN       := $(GOBIN)/nats-server.exe
DEVREDIS_BIN   := $(SERVER_ROOT)/tools/devredis/devredis.exe

# 5 个 Go main 进程（chat/logd/admin 当前是 stub，仅证明 boot 不 panic）
SERVICES := gateway world chat logd admin

.PHONY: build clean boot boot-test stop verify-middleware tinyclient

build: ## 编译全部 5 进程
	@echo ">>> building all $(words $(SERVICES)) services..."
	@cd $(SRC_DIR) && go build -o $(BIN_DIR)/ ./cmd/...
	@ls -la $(BIN_DIR)/*.exe

tinyclient: ## 单独编译 tinyclient
	@cd $(SRC_DIR) && go build -o $(BIN_DIR)/ ./cmd/tinyclient

clean: ## 删除编译产物
	@rm -f $(BIN_DIR)/*.exe
	@echo "bin/ cleaned (logs preserved)"

verify-middleware: ## 检查 PG 5432 / NATS 4222 / Redis 6379 是否在跑
	@echo ">>> verifying middleware ports..."
	@netstat -an -p tcp | grep -E "(:5432|:4222|:6379) " | grep LISTENING > /dev/null \
		|| (echo "FAIL: middleware ports not listening — run 'make boot' first" && exit 1)
	@echo "OK: PG / NATS / Redis are listening"

boot: build ## 启动中间件 + 5 进程（不跑 client）
	@mkdir -p $(LOG_DIR)
	@echo ">>> 1/3 starting NATS (4222)..."
	@if ! netstat -an -p tcp | grep -E ":4222 " | grep -q LISTENING; then \
		nohup "$(NATS_BIN)" -p 4222 > $(LOG_DIR)/nats.log 2>&1 & \
		sleep 1; \
	else echo "    (already running)"; fi
	@echo ">>> 2/3 starting devredis (6379, miniredis)..."
	@if ! netstat -an -p tcp | grep -E ":6379 " | grep -q LISTENING; then \
		nohup "$(DEVREDIS_BIN)" > $(LOG_DIR)/devredis.log 2>&1 & \
		sleep 1; \
	else echo "    (already running)"; fi
	@echo ">>> 3/3 starting 5 AionCore services..."
	@for svc in $(SERVICES); do \
		if ! tasklist 2>/dev/null | grep -qi "$$svc.exe"; then \
			AIONCORE_CONFIG_DIR=$(CONFIG_DIR) AIONCORE_DB_PASS=$${AIONCORE_DB_PASS:-postgres} \
				nohup "$(BIN_DIR)/$$svc.exe" > $(LOG_DIR)/$$svc.log 2>&1 & \
			echo "    $$svc started"; \
		else echo "    $$svc (already running)"; fi; \
	done
	@sleep 2
	@$(MAKE) -s verify-middleware
	@echo ">>> all up. PIDs:"
	@tasklist 2>/dev/null | grep -iE "nats-server|devredis|gateway.exe|world.exe|chat.exe|logd.exe|admin.exe" || true

boot-test: boot tinyclient ## 启动一切并跑端到端 tinyclient 验证
	@echo ">>> running tinyclient end-to-end smoke..."
	@$(BIN_DIR)/tinyclient.exe --account shiguang --password hunter2

stop: ## 停止 5 进程 + nats + devredis（不动 PostgreSQL 服务）
	@echo ">>> stopping AionCore + middleware..."
	@for proc in gateway.exe world.exe chat.exe logd.exe admin.exe nats-server.exe devredis.exe; do \
		taskkill //F //IM $$proc 2>/dev/null || true; \
	done
	@echo "stopped (PostgreSQL service untouched — managed by Windows SCM)"

help: ## 显示本帮助
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# -----------------------------------------------------------------
# Round 13 A1 追加 — CI 本地等价目标
#
# 作用域: 只跑 ./internal/... — cmd/spike 和 cmd/director 当前是 WIP，
# 用 ./... 会被它们带红。这与 .github/workflows/ci.yml 的 go-ci job 对齐。
# 详见 doc/ci.md。
# -----------------------------------------------------------------
.PHONY: lint test cover bench

lint: ## go vet on internal/
	cd $(SRC_DIR) && go vet ./internal/...

test: ## unit tests on internal/ (含 -race)
	cd $(SRC_DIR) && go test ./internal/... -count=1 -race -timeout=5m

cover: ## coverage report (打 coverage.out + 末行总覆盖率)
	cd $(SRC_DIR) && go test ./internal/... -count=1 -coverprofile=coverage.out -covermode=atomic
	cd $(SRC_DIR) && go tool cover -func=coverage.out | tail -1

bench: ## micro-benchmarks (crypto / luahost / database)
	cd $(SRC_DIR) && go test -run='^$$' -bench=. -benchtime=1x -benchmem ./internal/crypto ./internal/luahost ./internal/database 2>&1 | grep -E "(Benchmark|ns/op|ok)"

# -----------------------------------------------------------------
# Round 13 B4 追加 — golangci-lint 严格门 (debt ratchet 模式)
#
# 当前不强制 (CI 不 gate, 见 doc/lint.md); 提供本地命令让开发者按节奏修。
# 找到 baseline finding 数后写进 doc/lint.md TODO 段, 用户决策何时收紧。
# 安装: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
# -----------------------------------------------------------------
.PHONY: lint-strict lint-report
lint-strict: ## golangci-lint 跑 .golangci.yml 全 linter (不阻塞 — 仅信号)
	@cd $(SRC_DIR) && golangci-lint run --config $(SERVER_ROOT)/.golangci.yml ./internal/... 2>&1 \
		|| (echo ">>> lint findings exist; see doc/lint.md for ratchet plan" && exit 0)

lint-report: ## 把 lint findings 落到 doc/lint-baseline.txt 给 review
	@cd $(SRC_DIR) && golangci-lint run --config $(SERVER_ROOT)/.golangci.yml --out-format=tab ./internal/... > $(SERVER_ROOT)/doc/lint-baseline.txt 2>&1 || true
	@echo ">>> baseline written to doc/lint-baseline.txt"
