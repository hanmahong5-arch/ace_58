# AionCore 5.8 — Docker Bring-up 指南

一句话：在任何装了 Docker 的机器上，一条命令拉起 PostgreSQL + Redis + NATS + 5 个 AionCore 进程，等价于 `make boot`，但跨平台、零 Windows 路径折腾，并作为未来 prod 镜像的雏形。

---

## 1. 前置条件 / Prerequisites

| 工具 | 版本 | 说明 |
|------|------|------|
| Docker Engine | ≥ 24.0 | 24+ 才有稳定 BuildKit、`heredoc` 语法 |
| Docker Compose | ≥ v2.20 (plugin) | `docker compose` 而非 `docker-compose` |
| 内存 | ≥ 4 GB 给 Docker daemon | postgres + 5 svc + build 同时跑 |
| 磁盘 | ≥ 10 GB | 镜像层 ~120 MB + PG 数据卷 + build cache |

Windows 10/11：使用 Docker Desktop（WSL2 后端），或 Docker for Windows + Hyper-V。本仓库已在 Windows 10 + Docker Desktop 验证。

> 提示：如果你只想本机 dev 不要 Docker，请直接 `make boot`（需要 Windows + nats-server.exe + devredis.exe 已在 GOPATH/bin）。两条路并行存在、互不干扰。

---

## 2. 快速使用 / Quickstart

```bash
cd server

# 首次启动（编译 + 拉中间件镜像 + 起 8 容器）
docker compose -f docker-compose.dev.yml up -d --build

# 实时跟随 world 日志（最常用）
docker compose -f docker-compose.dev.yml logs -f world

# 健康检查
docker compose -f docker-compose.dev.yml ps

# 停服（保留 PG 数据）
docker compose -f docker-compose.dev.yml down

# 完全清空（连 PG 数据卷一起删）
docker compose -f docker-compose.dev.yml down -v
rm -rf deploy/data/pg     # 谨慎
```

启动后端口映射：

| 进程 | 容器端口 | 宿主端口 | 用途 |
|------|---------|---------|------|
| gateway | 2108 | **2208** | AION 客户端 auth |
| gateway | 7777 | **7877** | AION 客户端 game |
| admin   | 8080 | 8080    | GM REST API |
| redis   | 6379 | 6379    | 调试用 redis-cli |
| nats    | 4222 / 8222 | 4222 / 8222 | NATS client / monitor |
| postgres| 5432 | **不映射** | 仅集群内可见（红线：PG 永不暴露公网） |

把 5.8 客户端指向 `127.0.0.1:2208`/`127.0.0.1:7877` 即可登录。

---

## 3. 镜像构建说明 / Image Architecture

`Dockerfile` 用 multi-stage 模式：

| Stage | 基础镜像 | 作用 | 体积 |
|-------|---------|------|------|
| build   | `golang:1.25-alpine` | 编译全部 5 个 `cmd/<svc>` 静态二进制到 `/out` | ~ 800 MB（不进最终镜像） |
| runtime | `alpine:3.19` + tini | 拷贝 5 个二进制 + scripts/ + entrypoint.sh | **< 50 MB 目标** |

**单镜像多进程**：5 个 service 共享同一个镜像 tag `aioncore:dev`，运行时通过 `SERVICE` 环境变量选哪个二进制启动。优点：

- build 一次出 5 个进程，layer cache 共享
- 镜像版本对齐天然成立（gateway/world 必须同步发布，避免 RPC 不兼容）
- 容器启动 entrypoint 是 `/app/entrypoint.sh`，根据 `$SERVICE` `exec /app/$SERVICE`

> 反例：5 个独立 Dockerfile + 5 个 image tag。维护负担巨大、版本飘移风险高。已主动放弃。

**Layer 缓存策略**：

1. 先 `COPY src/go.mod src/go.sum` → `RUN go mod download`：依赖层只随 `go.mod` 变化失效
2. 再 `COPY src/`：业务代码改动只让最后一层失效，不会重新拉依赖

**编译选项**：`CGO_ENABLED=0` + `-trimpath` + `-ldflags="-s -w"`，单个 world 二进制约 12 MB。

---

## 4. compose service map

| 服务 | image / build | depends_on | 暴露 host | 数据持久化 |
|------|---------------|-----------|----------|-----------|
| postgres | postgres:17-alpine | — | （不映射） | `./deploy/data/pg` |
| redis    | redis:7-alpine | — | 6379 | 无（dev 重启即清） |
| nats     | nats:2-alpine `-js` | — | 4222, 8222 | 无 |
| gateway  | aioncore:dev (build) | postgres, redis, nats | 2208, 7877 | 无 |
| world    | aioncore:dev | postgres, redis, nats | — | （DB 内） |
| chat     | aioncore:dev | postgres, redis, nats | — | — |
| logd     | aioncore:dev | postgres, redis, nats | — | — |
| admin    | aioncore:dev | postgres, redis, nats | 8080 | — |

`depends_on` 使用 `condition: service_healthy`，所以 5 个 AionCore 进程一定在 PG `pg_isready` 通过、Redis `PING` 通过之后才启动 —— 避免 cold start 时 world 抢先建连撞墙。

---

## 5. 数据持久化 / Data Persistence

| 数据 | 路径 | 备注 |
|------|------|------|
| PostgreSQL data | `server/deploy/data/pg` | bind mount，宿主可见。git ignored 的目录建议另外加 |
| Redis | 无 | dev 重启清空（`--save ""` + `--appendonly no`） |
| NATS streams | 无 | dev 重启清空（JetStream 仅内存） |

**4 个数据库** (`aion_world_live` / `aion_account_db` / `aion_account_cache_db` / `aion_gm`) 由 `deploy/pg-init/01_create_databases.sql` 在 PG 容器首启时自动创建。schema 由 world 进程的 goose embed 迁移落库（`internal/database/migrate.go` 通过 `go:embed` 把 `internal/database/migrations/*.sql` 烤进 world 二进制，运行时不读磁盘）。

---

## 6. 配置 / Configuration

镜像**不内置 config**。两套 TOML 并存：

- `server/config/*.toml` —— host 上 `make boot` 用，hostname 全是 `127.0.0.1`
- `server/deploy/config-docker/*.toml` —— Docker 用，hostname 是 `postgres` / `redis:6379` / `nats:4222`

compose 把 `./deploy/config-docker` 以 read-only 方式 bind 到容器 `/etc/aioncore`。改 TOML 不需要重新 build 镜像，只需 `docker compose restart <svc>`。

> RSA 私钥 `config/rsa_private.pem` 单独 bind mount 到 gateway 容器，不进镜像（避免密钥泄漏到 image registry）。

**密码注入**：

```bash
# 默认 PG 密码 = "postgres"，要换：
AIONCORE_DB_PASS='your-secret' docker compose -f docker-compose.dev.yml up -d
```

`AIONCORE_DB_PASS` 同时被 postgres 容器（设密码）和 5 个 AionCore 容器（连接密码）读到，保持一致性。

---

## 7. 与 `make boot` 的关系

| 维度 | `make boot` (Windows host) | `docker compose up` |
|------|--------------------------|---------------------|
| 平台 | 仅 Windows，依赖 nats-server.exe + devredis.exe | macOS / Linux / WSL2 / Windows Docker |
| 中间件 | 走 Windows SCM 的 PostgreSQL 服务 + 临时 nats + miniredis | 全部容器化 |
| 启动速度 | ~3 秒（已编译） | 首次 ~60 秒（build），后续 ~10 秒 |
| 端口 | 2108/7777 (prod profile) | 2208/7877 (dev profile，避撞 prod) |
| 隔离性 | 进程级，共享 host 文件系统 | 容器级，network 隔离 |
| 适用场景 | 本地写代码-编译-跑测试-改代码循环 | 多机协作 dev / CI 集成 / 重置环境演练 |

**两条路完全等价**，由开发者按需选择。Hot-reload Lua 在两边都工作（compose 模式下 scripts/ 是镜像 bake 的，要测改动需 `docker compose build && up -d`，或者把 scripts/ 也 mount 进去 —— 详见 §10）。

---

## 8. 故障排查 / Troubleshooting

### 8.1 `postgres` 不健康

```bash
docker compose -f docker-compose.dev.yml logs postgres
```

常见原因：
- 数据卷权限问题（Linux 上 `deploy/data/pg` 属主不是 999） → `sudo chown -R 999:999 deploy/data/pg`
- 端口 5432 被宿主已有 PG 占用 → 仅集群内可见，不映射宿主，所以**不会冲突**。如果你看到 "address already in use" 那一定是误改了 ports

### 8.2 migration 失败 → world Exit 1

```bash
docker compose -f docker-compose.dev.yml logs world | grep -i migrate
```

- 大概率是 PG 容器还没就绪，但 `depends_on: condition: service_healthy` 已经规避；如果仍然出现，说明 healthcheck 标准过松，把 retries 往上加
- 紧急逃生：`AIONCORE_SKIP_MIGRATIONS=1 docker compose up -d world`（**不要在 prod 用**）

### 8.3 端口冲突（2208 / 7877 / 8080 被占用）

```bash
# Windows 下查谁占了 2208
netstat -ano | findstr :2208

# 修改宿主端口（编辑 docker-compose.dev.yml 的 ports 段）
ports:
  - "12208:2108"   # 改成 12208
```

### 8.4 镜像太大（> 50 MB）

体积超标通常意味着误把 client/ 或 tools/ 进了 build context。检查 `.dockerignore` 是否生效：

```bash
docker build -t aioncore:dev -f Dockerfile . --progress=plain 2>&1 | head -5
# 看 "transferring context: 几 MB" 行；如果是几个 GB 一定是 .dockerignore 没排除大资产
```

### 8.5 Lua 改动不生效

- compose 模式下 scripts/ 在镜像里，**改完要 rebuild**：`docker compose build world && docker compose up -d world`
- 如果你想要 host 编辑实时反映到容器，把 scripts/ 也 bind mount（**请在 host 改 docker-compose.dev.yml**）：
  ```yaml
  world:
    volumes:
      - ./scripts:/app/scripts:ro    # 加这行
  ```
  然后 world 进程的 fsnotify 会监到改动，1 秒内 hot-reload，不需要重启容器。

---

## 9. 不进 prod 的清单 / Not Production-Ready

本 compose 是 **dev 蓝本**，迁移到 prod 之前必须补：

| 项 | dev 当前状态 | prod 必须做 |
|----|------------|-----------|
| 镜像 SHA 校验 | 无（用 `aioncore:dev` tag） | 用 SHA256 digest pin，签名校验 |
| Secret 注入 | 环境变量明文 | Docker secrets / Vault / K8s Secret |
| TLS | 全部明文 | gateway ↔ client 维持 AION 自有协议；admin REST 必须 TLS；PG / Redis / NATS 集群间 mTLS |
| PG 暴露 | 仅 expose 给同网络 | 加防火墙规则、`pg_hba.conf` 收紧、备份策略 |
| 资源限制 | 无 | 每个 service 加 `deploy.resources.limits` |
| 日志收集 | docker logs stdout | logd 接 ClickHouse + Promtail/Loki |
| 健康端点 | 仅基础 healthcheck | gateway/world 暴露 `/healthz` + `/readyz`，K8s probe 接入 |
| 滚动升级 | 无 | K8s manifests / Helm chart |
| 容量规划 | dev 默认 | postgres tuning、redis maxmemory、NATS JetStream 容量 |

prod 部署 artifact 留在 `deploy/`，未来按需加 K8s manifests / systemd units / Helm charts。

---

## 10. 进阶：开发模式 hot-reload

如果你想容器化跑、但 Lua 还要 host 编辑实时生效：

```yaml
# 在 docker-compose.dev.yml 的 world 段加（或维护 docker-compose.dev.override.yml）
world:
  volumes:
    - ./scripts:/app/scripts:ro
```

Go 代码改动仍需 rebuild（`docker compose build world && docker compose up -d world`）。如要 Go 也热重启，请走 `make boot` 路线（host 直接编译 + 进程 supervisor），不要 Docker。
