// Package ipc defines the NATS JetStream event bus used for inter-service
// communication between the Protocol Gateway and the World Engine.
//
// Subject naming convention:
//   player.*     — lifecycle events published by Gateway, consumed by World
//   world.*      — responses published by World, consumed by Gateway
//   cm.*         — raw CM_* packet payloads (Gateway → World)
//   sm.*         — raw SM_* packet payloads (World → Gateway)
//
// All payloads are JSON-encoded.
package ipc

// Subject constants — all services must use these exact strings.
const (
	// SubjectPlayerLogin is published by Gateway after auth completes.
	// World stores the session state but does NOT send a character list yet.
	SubjectPlayerLogin = "player.login"

	// SubjectPlayerEnter is published by Gateway after CM_SESSION_CONFIRM succeeds.
	// World responds with world.enter_ack, then fetches and sends the character list.
	SubjectPlayerEnter = "player.enter"

	// SubjectPlayerLeave is published by Gateway when a client disconnects.
	SubjectPlayerLeave = "player.leave"

	// SubjectWorldEnterAck is published by World as a reply to player.enter.
	SubjectWorldEnterAck = "world.enter_ack"

	// SubjectWorldSM is the prefix for World→Gateway SM_* packet delivery.
	// Full subject: "world.sm.{gatewaySessionID}"
	SubjectWorldSM = "world.sm"

	// SubjectPlayerCM is the prefix for Gateway→World CM_* packet delivery.
	// Full subject: "player.cm.{gatewaySessionID}"
	// Use instead of hard-coding the literal at publish/subscribe sites so a
	// future rename cannot desynchronize producer and consumer.
	SubjectPlayerCM = "player.cm"
)

// PlayerLoginEvent is published after the auth port handshake completes.
type PlayerLoginEvent struct {
	AccountID int64  `json:"account_id"`
	Account   string `json:"account"`
	ServerID  int    `json:"server_id"`
	TokenHex  string `json:"token_hex"` // hex form of session token (for logging only)
	RemoteAddr string `json:"remote_addr"`
}

// PlayerEnterEvent is published after the game port CM_SESSION_CONFIRM is verified.
// The Gateway's session ID is included so World can route SM_* responses back.
type PlayerEnterEvent struct {
	AccountID     int64  `json:"account_id"`
	Account       string `json:"account"`
	GatewaySeqID  uint64 `json:"gateway_seq_id"` // Session.id from gateway
	RemoteAddr    string `json:"remote_addr"`
}

// PlayerLeaveEvent is published when a client disconnects from the game port.
type PlayerLeaveEvent struct {
	AccountID    int64  `json:"account_id"`
	GatewaySeqID uint64 `json:"gateway_seq_id"`
	Reason       string `json:"reason"` // "disconnect" | "timeout" | "kicked"
}

// WorldEnterAckEvent is published by World in response to player.enter.
type WorldEnterAckEvent struct {
	GatewaySeqID uint64 `json:"gateway_seq_id"`
	Status       string `json:"status"` // "ok" | "error"
	Message      string `json:"message,omitempty"`
}

// PacketEvent carries an encoded CM_* or SM_* packet over NATS.
// Used for the gameplay loop once the handshake is complete (Phase S-2+).
type PacketEvent struct {
	GatewaySeqID uint64 `json:"gateway_seq_id"`
	Opcode       uint16 `json:"opcode"`
	Payload      []byte `json:"payload"` // raw packet bytes after opcode
}
