# syntax=docker/dockerfile:1.7
#
# AionCore 5.8 — multi-stage container image
#
# 设计目标:
#   - 一个镜像，五个进程: gateway / world / chat / logd / admin。
#     运行时通过 SERVICE 环境变量决定要起哪一个二进制。
#   - 构建阶段: golang:1.25-alpine 编译全部 5 个 ./cmd/<svc>，统一输出到 /out。
#   - 运行阶段: alpine:3.19 (~7 MB base) + 5 个静态链接 Go 二进制 + Lua 脚本资产，
#     最终镜像 < 50 MB（CGO_ENABLED=0 + alpine + scripts only）。
#   - 不在镜像里 bake config/。配置由 docker-compose 以 read-only volume 注入到
#     /etc/aioncore，方便本机改 TOML 不重新 build。
#
# 用法 (单镜像 → 多进程):
#   docker build -t aioncore:dev -f Dockerfile .
#   docker run --rm -e SERVICE=gateway -e AIONCORE_DB_PASS=postgres aioncore:dev
#
# 通常你不会直接 docker run，请使用 docker-compose.dev.yml 一键拉起。

# -----------------------------------------------------------------------------
# Stage 1: build — 静态编译全部 5 个进程
# -----------------------------------------------------------------------------
FROM golang:1.25-alpine AS build

# git 留着给 go mod download 走 https；其它工具一律不装，保持 build 容器精简
RUN apk add --no-cache git ca-certificates

WORKDIR /src

# 先单独拷贝 go.mod / go.sum 触发 layer 缓存：
# 只要这两个文件没变，下面的 go mod download 这层就能命中缓存，
# 不需要每次改一行业务代码就重新拉 200 MB 依赖。
COPY src/go.mod src/go.sum ./
RUN go mod download

# 拷贝实际源码（这层会随业务代码改动而失效，符合预期）
COPY src/ ./

# CGO_ENABLED=0 → 完全静态二进制，可以放进 distroless / scratch / alpine 都不带 libc 麻烦。
# -trimpath 抹掉本机绝对路径; -ldflags="-s -w" 去掉调试符号，单个 world 二进制 ~17 MB → ~12 MB。
# 一次构建编出 5 个，统一落到 /out 方便 stage 2 拷贝。
RUN CGO_ENABLED=0 GOOS=linux \
    go build -trimpath -ldflags="-s -w" \
    -o /out/ \
    ./cmd/gateway ./cmd/world ./cmd/chat ./cmd/logd ./cmd/admin

# -----------------------------------------------------------------------------
# Stage 2: runtime — alpine + 静态二进制 + Lua 脚本
# -----------------------------------------------------------------------------
FROM alpine:3.19 AS runtime

# 运行时只需要 ca-certificates（PG TLS / 出站 HTTPS 才会用上）+ tini（PID 1 信号转发）。
# 不装 bash / sh extras，保持 attack surface 小。
RUN apk add --no-cache ca-certificates tini \
 && addgroup -S aion && adduser -S -G aion -u 10001 aion \
 && mkdir -p /app /etc/aioncore /var/log/aioncore \
 && chown -R aion:aion /app /var/log/aioncore

WORKDIR /app

# 拷贝 5 个二进制（单镜像多进程，运行时由 SERVICE env 选）
COPY --from=build /out/gateway /out/world /out/chat /out/logd /out/admin /app/

# Lua 脚本必须随镜像走 (world 进程 hot-reload watch 这个目录)。
# scripts/ 体积小 (~几 MB)，全量 COPY 不影响镜像体积目标 < 50 MB。
COPY --chown=aion:aion scripts/ /app/scripts/

# 默认 entrypoint 脚本 — 按 SERVICE 选二进制。
# 写法保持 POSIX sh 兼容（alpine 默认 ash）。
COPY --chown=aion:aion <<'EOF' /app/entrypoint.sh
#!/bin/sh
# AionCore 单镜像多进程 dispatcher。
# 必填:  SERVICE=gateway|world|chat|logd|admin
# 可选:  AIONCORE_CONFIG_DIR (默认 /etc/aioncore)
#        AIONCORE_DB_PASS    (PG 密码; 否则 gateway/world 启动会拿空密码)
set -eu

: "${SERVICE:?SERVICE env var required (gateway|world|chat|logd|admin)}"
export AIONCORE_CONFIG_DIR="${AIONCORE_CONFIG_DIR:-/etc/aioncore}"

case "$SERVICE" in
    gateway|world|chat|logd|admin) ;;
    *) echo "unknown SERVICE=$SERVICE; must be one of gateway/world/chat/logd/admin" >&2; exit 64 ;;
esac

# scripts 目录只对 world 是必需的，但镜像统一带上，避免按 svc 分镜像造成维护负担。
cd /app
exec "/app/$SERVICE"
EOF
RUN chmod +x /app/entrypoint.sh

USER aion

# 暴露 dev 端口范围:
#   2208 — gateway auth (dev profile)
#   7877 — gateway game (dev profile)
#   2108 — gateway auth (prod profile，备用)
#   7777 — gateway game (prod profile，备用)
#   8080 — admin REST
#   10241 — chat
# 仅声明，不强制；compose 文件会按 service 选择真正映射哪个。
EXPOSE 2108 2208 7777 7877 8080 10241

# tini 当 PID 1: SIGTERM 干净传递到 Go 进程，避免 docker stop 走 10s 超时。
ENTRYPOINT ["/sbin/tini", "--", "/app/entrypoint.sh"]
