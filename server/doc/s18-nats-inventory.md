# S-18 NATS Event-Flow Inventory

Date: 2026-04-22
Scope: `internal/ipc/` + `cmd/**/*.go`

## 1. Event Types Declared (`internal/ipc/events.go`)

| Struct | Fields | Notes |
|---|---|---|
| `PlayerLoginEvent`     | AccountID, Account, ServerID, TokenHex, RemoteAddr     | Auth-port handshake complete |
| `PlayerEnterEvent`     | AccountID, Account, GatewaySeqID, RemoteAddr           | Game-port CM_SESSION_CONFIRM OK |
| `PlayerLeaveEvent`     | AccountID, GatewaySeqID, Reason                        | Disconnect |
| `WorldEnterAckEvent`   | GatewaySeqID, Status, Message                          | **Declared, never used** |
| `PacketEvent`          | GatewaySeqID, Opcode, Payload                          | CM_*/SM_* transport |

**Total: 5 event types.**

## 2. Subject Constants

| Const | Value | Shape |
|---|---|---|
| `SubjectPlayerLogin`    | `player.login`      | static |
| `SubjectPlayerEnter`    | `player.enter`      | static |
| `SubjectPlayerLeave`    | `player.leave`      | static |
| `SubjectWorldEnterAck`  | `world.enter_ack`   | static |
| `SubjectWorldSM`        | `world.sm`          | prefix — full subject `world.sm.{gatewaySeqID}` |
| (unnamed)               | `player.cm`         | prefix — `player.cm.{gatewaySeqID}`, hard-coded at both sites |

Convention: `<producer>.<topic>[.{sessionID}]`; payloads JSON; per-session subjects use numeric suffix.

## 3. Publish Sites

| Subject | File:Line | Method |
|---|---|---|
| `player.login`           | cmd/gateway/main.go:269 | PublishAsync |
| `player.leave`           | cmd/gateway/game.go:39  | PublishAsync |
| `player.enter`           | cmd/gateway/game.go:110 | Publish (sync flush) |
| `player.cm.{id}`         | cmd/gateway/game.go:153 | PublishAsync |
| `world.sm.{id}`          | cmd/world/dispatcher.go:193, 238 | PublishAsync (x2 in send paths) |

## 4. Subscribe Sites

| Subject | File:Line | Handler |
|---|---|---|
| `player.enter`           | cmd/world/main.go:132          | `Dispatcher.onPlayerEnter` |
| `player.leave`           | cmd/world/main.go:140          | `Dispatcher.onPlayerLeave` |
| `player.cm.{id}`         | cmd/world/dispatcher.go:62     | `Dispatcher.dispatchCM` (per-session) |
| `world.sm.{id}`          | cmd/gateway/game.go:122        | forwards SM_* frame to client (per-session) |

## 5. Pairing Analysis

| Event | Publisher | Subscriber | Status |
|---|---|---|---|
| `player.login`      | gateway    | **none**       | **DEAD PUBLISHER** — fire-and-forget log signal only |
| `player.enter`      | gateway    | world          | Wired |
| `player.leave`      | gateway    | world          | Wired |
| `player.cm.{id}`    | gateway    | world (per session) | Wired |
| `world.sm.{id}`     | world      | gateway (per session) | Wired |
| `world.enter_ack`   | **none**   | **none**       | **ORPHAN CONSTANT** — type + subject declared, no code path |

**Wired end-to-end: 4 of 5 event types (80%).**
**Orphaned: `PlayerLoginEvent` has a publisher but no consumer; `WorldEnterAckEvent` is fully dead (type + subject with no publish or subscribe).**

## 6. JetStream Usage

**None.** Despite the package doc string ("NATS JetStream event bus"), `internal/ipc/nats.go` uses only core NATS pub/sub (`nats.Conn.Publish`, `nats.Conn.Subscribe`, `nats.Conn.Request`). No streams, no durables, no `jetstream.New`, no ack handling. Messages are fire-and-forget with at-most-once semantics.

## 7. Routing Bugs Discovered

1. **`SubjectWorldEnterAck` + `WorldEnterAckEvent` are dead code** — declared in events.go with docstrings stating "published by World in response to player.enter", but World never publishes and Gateway never subscribes. Either implement the ack handshake (Gateway currently blind-trusts that World received the enter event) or remove the declarations. Left in place for now; flagged as a future cleanup.

2. **`player.login` has no consumer.** Gateway publishes on auth success, but no service subscribes. This is not a runtime bug (NATS core silently drops), but it is wasted serialization work on the hot path. Consider removing or giving it a consumer (metrics/logd).

3. **`player.cm.*` subject string is hard-coded at two sites** (publisher and subscriber) with no shared constant. A future rename would miss one side. A constant `SubjectPlayerCMPrefix = "player.cm"` should live in events.go.

4. **Package doc claims JetStream** but implementation is core NATS. Misleading.

## 8. Recommendations

- **NATS is scaffolding, not load-bearing.** Every publisher has a `PublishAsync` fallback that silently drops on a nil client, every subscriber returns a no-op unsub. The server runs fine in single-process mode with `NewNilClient()`. NATS is required only when Gateway and World run on separate hosts.
- Add the `SubjectPlayerCMPrefix` constant (surgical, done in this PR — see follow-up patch notes).
- Defer JetStream migration until actual load demands guaranteed delivery.
