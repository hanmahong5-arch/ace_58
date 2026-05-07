# AionCore 5.8 Server

[![CI](https://github.com/<org>/<repo>/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/<org>/<repo>/actions/workflows/ci.yml)
[![Go Version](https://img.shields.io/badge/go-1.25-blue)](https://go.dev/)
[![License](https://img.shields.io/badge/license-Internal-lightgrey)](#)
[![Tests](https://img.shields.io/badge/tests-381%20pass-brightgreen)](#)
[![Coverage](https://img.shields.io/badge/coverage-69.5%25-yellow)](./doc/coverage.md)

> English README · [中文](./README.zh-CN.md) · [Architecture](./doc/architecture.md) · [Changelog](./CHANGELOG.md) · [Contributing](./CONTRIBUTING.md) · [ADRs](./doc/adr/README.md) · [Runbook](./doc/runbook.md)

A from-scratch **Go + Lua + PostgreSQL** reimplementation of the NCSoft AION 5.8 game server.

---

## TL;DR

- **What**: rebuild NCSoft 5.8 protocol + 1314 PL/pgSQL stored procedures + combat / dungeon / quest
  business logic on a custom Go runtime + Lua sandbox. **Not a binary mod** — a fresh reference
  implementation of the AION protocol.
- **Why**: a real-server mod ceiling is ~30%; a self-written server reaches ~85%, which is the
  carrier for the "high-entropy AION private server" thesis (see `../CLAUDE.md`).
- **Scope of this directory**: server code, configs, scripts, tools, docs. Game client lives in
  `../client/`; archived C++ / Rust attempts live under `../../_archive/`.

---

## Architecture (one diagram)

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1 ── Go runtime (thin; rarely touched)               │
│  network I/O · packet codec · BF-LE / RSA / XOR · pgx pool  │
│  ECS · Redis · NATS · TOML config · structured logging      │
└─────────────────────────────────────────────────────────────┘
                              ↓ exposes globals
┌─────────────────────────────────────────────────────────────┐
│  Layer 2 ── Lua scripts (thick; daily churn; 1s hot-reload) │
│  scripts/{handlers,skills,combat,ai,quests,events,…}        │
└─────────────────────────────────────────────────────────────┘
                              ↓ db.call("aion_xxx", …)
┌─────────────────────────────────────────────────────────────┐
│  Layer 3 ── PostgreSQL stored procedures (stable; minimal)  │
│  ~1314 PL/pgSQL functions · atomic state · transactions     │
└─────────────────────────────────────────────────────────────┘
```

Five processes, not seventeen: **gateway / world / chat / logd / admin**.

---

## Quick Start

```bash
# Install deps
cd server
go -C src mod download

# Bring up middleware (PG / Redis / NATS) — see doc/docker.md
docker compose -f docker-compose.dev.yml up -d

# Build all 5 services to ./bin/
make build

# Run end-to-end smoke (boot middleware + 5 services + tinyclient)
make boot-test

# Stop everything (PostgreSQL service untouched)
make stop

# Run tests / lint / cover / bench (CI-equivalent)
make help        # list every target
```

Environment variables:

- `AIONCORE_DB_PASS` — PG password (default: `postgres`)
- `AIONCORE_CONFIG_DIR` — TOML config dir (Makefile auto-sets to `./config/`)

---

## Hard Constraints (memorize these)

1. **NEVER write inline SQL in Go or Lua** — only call the 1314 migrated PL/pgSQL stored procedures.
2. **NEVER expose PostgreSQL to the internet** — `127.0.0.1` only (ransomware lesson: 2026-04-11).
3. **NEVER hardcode values** — every port / rate / dungeon param goes through TOML or PG.
4. **Blowfish is little-endian** — NCSoft non-standard; the Go stdlib `crypto/blowfish` is big-endian
   and **must not be used**. See `internal/crypto/blowfish_le.go`.
5. **Account name ≤ 17 chars** — RSA-1024 credential block size limit.
6. **XOR order: XOR-first, ADD-stored, seed = 1234** — the AL-Login reverse order corrupts session keys.
7. **5.8 client ignores XOR checksum** — accept payload even when the checksum bit fails.
8. **All game logic in Lua** — Go is for network / ECS / DB pool / Lua VM hosting only.

Full list with rationale: [`doc/dev-guide.md`](./doc/dev-guide.md).

---

## Doc Map

| Topic | Doc |
|-------|-----|
| Source of Truth (hard constraints) | [`doc/dev-guide.md`](./doc/dev-guide.md) |
| **SP migration ledger** (240/1059, 23 batches) | [`doc/migration/STATUS.md`](./doc/migration/STATUS.md) |
| Architecture (process topology, data flow) | [`doc/architecture.md`](./doc/architecture.md) |
| Lua API surface | [`doc/lua-api.md`](./doc/lua-api.md) |
| Opcode table | [`doc/opcodes.md`](./doc/opcodes.md) |
| CI pipeline | [`doc/ci.md`](./doc/ci.md) |
| Observability | [`doc/observability.md`](./doc/observability.md) |
| Coverage | [`doc/coverage.md`](./doc/coverage.md) |
| Benchmarks | [`doc/benchmarks.md`](./doc/benchmarks.md) |
| First-boot checklist | [`doc/dev-boot-checklist.md`](./doc/dev-boot-checklist.md) |
| ADRs (decisions) | [`doc/adr/README.md`](./doc/adr/README.md) |
| Runbook (oncall) | [`doc/runbook.md`](./doc/runbook.md) |

---

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). TL;DR: TDD, single-concern PRs, never push `main`,
never bind PG to `0.0.0.0`.

History: [`CHANGELOG.md`](./CHANGELOG.md).

---

## Legal

NCSoft 5.8 client binaries remain NCSoft copyright; this server is for a 1–100 person QQ-group
private server only, **non-commercial**. Server source code is original; protocol is referenced,
not copied.
