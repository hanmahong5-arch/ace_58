# Admin REST API

> AionCore 5.8 GM 控制面。`cmd/admin` 进程提供：JWT 鉴权 + 三角色 RBAC + 双速率限制 + 端点 stub（业务实装由后续 round 接 PG SP）。
> 监听地址硬编码 `127.0.0.1:8080`，**绝不直暴露公网**——外网走反向代理 + TLS。
>
> 配套文档：[`./observability.md`](./observability.md) · [`./runbook.md`](./runbook.md) · [`./architecture.md`](./architecture.md)

## 设计要点（一眼看懂）

| 维度 | 选型 | 理由 |
|------|------|------|
| Router | `chi v5` | stdlib `http.Handler` 风格，零反射，路由树清晰 |
| Auth | JWT HS256 + bcrypt | 单进程部署无需 RSA 公私分离；密钥 ≥32B 启动期硬校 |
| RBAC | 三角色硬编码 | superadmin / gm / readonly；≤10 GM 团队，PG `admin_users` 表迁移 TODO |
| Rate Limit | `golang.org/x/time/rate` token bucket | 登录 IP 桶 5/min；/api/v1 sub 桶 60/sec |
| Logger | `slog` JSON | 与 logd 链路一致 |

## 启动

```bash
# 1) 生成 ≥32B HS256 密钥
export AION_ADMIN_JWT_SECRET="$(openssl rand -hex 32)"   # 64 hex = 32 字节

# 2) 启动
./admin
# 监听 127.0.0.1:8080；密钥未设或 <32 字节会 fatal exit
```

## Middleware 顺序（顺序错=安全洞）

```
Recoverer → RequestID → Logger → CORS → RateLimit → Auth → handler
```

理由：

1. **Recoverer 最外** — 兜底任何 panic 不让进程崩
2. **RequestID** — 让后续 Logger 能打 req_id
3. **Logger** — 打访问日志（含 req_id）
4. **CORS** — 处理 preflight；前端跨域必经
5. **RateLimit** — 在 Auth 前；防"无效凭证 + 暴力 burst"打满 bcrypt CPU
6. **Auth** — 解析 JWT、注入 claims 到 context
7. **handler** — 业务

## 路由表

### 公开端点（不限速 / 不鉴权）

| 方法 | 路径 | 用途 | 实装 |
|------|------|------|------|
| `GET` | `/healthz` | k8s liveness | ✅ |
| `GET` | `/metrics` | Prometheus 抓取 | ✅ |

### 半公开（IP 桶限速 5/min）

| 方法 | 路径 | 用途 | 实装 |
|------|------|------|------|
| `POST` | `/admin/login` | 用户名密码换 JWT | ✅ |

### 鉴权区（JWT + sub 桶 60/sec + RBAC）

所有端点前缀 `/api/v1`。Authorization 走 cookie `admin_token` **或** `Authorization: Bearer <token>`（双发兜底）。

| 方法 | 路径 | 角色 | 用途 | 实装 |
|------|------|------|------|------|
| `GET` | `/api/v1/players` | superadmin/gm/readonly | 列在线玩家 | stub（TODO PG SP） |
| `GET` | `/api/v1/players/{id}` | superadmin/gm/readonly | 取某玩家概览 | stub |
| `POST` | `/api/v1/players/{id}/ban` | superadmin/gm | 封号 | stub |
| `POST` | `/api/v1/players/{id}/kick` | superadmin/gm | 踢线 | stub |
| `GET` | `/api/v1/server/stats` | superadmin/gm/readonly | 服务器快照 | stub |

stub 端点返回结构化 JSON，含 `note` 字段标记 `TODO: wire PG SP / NATS dispatch`，前端可对接联调。

## 鉴权细节

### 登录 → 拿 token

```http
POST /admin/login HTTP/1.1
Content-Type: application/json

{"username": "sadmin", "password": "..."}
```

成功响应（HTTP 200）：

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "role": "superadmin",
  "expires_at": 1717891234
}
```

同时 Set-Cookie：`admin_token=...; HttpOnly; Path=/; SameSite=Strict; Max-Age=7200`。

失败：HTTP 401 + `{"error": "invalid credentials"}`。**5 次/分钟** 触发 IP 桶 → HTTP 429。

### 携带 token 请求

二选一（任一即可）：

- Cookie：`Cookie: admin_token=...`（浏览器自动发，HttpOnly 防 XSS 偷）
- Header：`Authorization: Bearer ...`（curl/SDK 友好）

### JWT claims

```json
{
  "sub": "sadmin",
  "role": "superadmin",
  "iat": 1717884034,
  "exp": 1717891234,
  "jti": "<16B 随机十六进制>"
}
```

- `tokenTTL = 2h`：平衡"无感续期"与"被盗损失窗口"
- `jti`：未来要做主动撤销时按此黑名单
- 算法白名单 `["HS256"]`：拒绝 `alg=none` / RS256-key-as-HMAC 降级攻击

## 角色矩阵

| 操作 | superadmin | gm | readonly |
|------|:---------:|:--:|:--------:|
| 查询玩家 | ✅ | ✅ | ✅ |
| Ban/Kick | ✅ | ✅ | ❌ |
| 服务器快照 | ✅ | ✅ | ✅ |
| （未来）改 GM 表 | ✅ | ❌ | ❌ |

`requireRole(...allowed) → middleware`：未匹配 → HTTP 403。

## 速率限制

两个独立桶：

- **登录桶**（key=IP）：`rate.Every(time.Minute/5)`，burst=5。**针对暴力破解**。
- **API 桶**（key=sub，未鉴权时退回 IP）：`rate.Every(time.Second)`，burst=60。**针对突发查询合理放行**，稳态 1Hz。

实现细节：

- 用 `map[key]*rate.Limiter` + `sync.RWMutex`，**非 sync.Map**。RWMutex 让 GC 时能 atomic 切 snapshot 重建表。
- GC goroutine 跟 ctx 联动，进程退出自动收线（不漏 goroutine）。

429 响应：

```json
{"error": "rate limit exceeded", "retry_after_sec": 12}
```

## 已知限制 / TODO

1. **用户库硬编码** — auth.go 里固化了 superadmin/sadmin-dev-pwd（开发引导用），生产部署前必须迁 PG `admin_users(login, passhash, role, disabled)` + bcrypt cost ≥12
2. **业务端点都是 stub** — `listPlayers/getPlayer/...` 全部待接 PG SP
3. **CORS 默认允许所有来源** — 生产前按白名单收紧（前端域名 + 反代域名）
4. **没有审计日志** — Ban/Kick 等敏感动作未持久化操作记录；接 PG `gm_audit_log` 表 + slog WARN
5. **JWT 撤销** — 当前仅靠 TTL 自动失效；要做"立即吊销"需要 `jti` 黑名单（Redis SET，TTL = remaining_exp）

## 测试

```bash
cd D:/拾光ai/ACE_5.8/server/src
go test ./cmd/admin -v -count=1
```

25 个 PASS：auth (8) · middleware (5) · rbac (4) · router (8)。覆盖：JWT 签发 / 验证 / alg-none 拒绝 / 过期 / 角色守卫 / 限速 burst / login bcrypt 兼容 / 429 响应。
