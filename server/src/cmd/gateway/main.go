// Package main implements the AionCore Protocol Gateway (Phase S-1).
//
// Responsibilities:
//   - Accept AION 5.8 client connections on :2108 (auth) and :7777 (game).
//   - BF-LE / RSA / XOR crypto handshake on the auth port.
//   - Issue Redis-backed one-time session tokens on CM_PLAY.
//   - Publish player.login / player.enter / player.leave to NATS.
//   - Forward SM_* events from NATS to the appropriate client session.
//
// Zero game logic lives here. If you are writing combat/skill/quest code in
// gateway, you are doing it wrong — put it in Lua scripts instead.
package main

import (
	"context"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"log/slog"
	mrand "math/rand"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"aion58/internal/aionproto"
	"aion58/internal/config"
	"aion58/internal/crypto"
	"aion58/internal/database"
	"aion58/internal/ipc"
	"aion58/internal/session"

	goredis "github.com/redis/go-redis/v9"
)

func main() {
	// Structured JSON logging — compatible with ClickHouse log ingestion.
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelDebug,
	})))

	// Resolve config directory from env or the default relative path.
	configDir := envOrDefault("AIONCORE_CONFIG_DIR", "../../config")

	loader, err := config.NewLoader(configDir)
	if err != nil {
		slog.Error("gateway: config loader init failed", "err", err)
		os.Exit(1)
	}
	defer loader.Close()

	gatewayCfg, err := loader.LoadGateway()
	if err != nil {
		slog.Error("gateway: load gateway.toml", "err", err)
		os.Exit(1)
	}

	// Load (or auto-generate) RSA-1024 key pair.
	rsaKP, err := crypto.LoadRSAKeyPair(gatewayCfg.Crypto.RSAKeyFile)
	if err != nil {
		slog.Error("gateway: RSA key setup failed", "err", err)
		os.Exit(1)
	}
	slog.Info("gateway: RSA key pair ready")

	// Decode the static Blowfish key once at startup.
	bfKeyBytes, err := hex.DecodeString(gatewayCfg.Crypto.BFStaticKey)
	if err != nil {
		slog.Error("gateway: invalid bf_static_key hex", "err", err)
		os.Exit(1)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Connect to PostgreSQL (aion_account_db) for credential verification.
	var db *database.Pool
	db, err = database.NewPool(ctx, gatewayCfg.Database.PoolDSN())
	if err != nil {
		// Non-fatal: gateway starts in dev mode, accepts any credentials.
		slog.Warn("gateway: database unavailable at startup (dev mode active)", "err", err)
		db = nil
	} else {
		defer db.Close()
	}

	// Connect to Redis for session token storage.
	var tokenStore session.TokenStoreIface
	rdb := goredis.NewClient(&goredis.Options{
		Addr:     gatewayCfg.Redis.Addr,
		DB:       gatewayCfg.Redis.DB,
		PoolSize: gatewayCfg.Redis.PoolSize,
	})
	if pingErr := rdb.Ping(ctx).Err(); pingErr != nil {
		slog.Warn("gateway: Redis unavailable — NilStore active (tokens always accepted)", "err", pingErr)
		_ = rdb.Close()
		tokenStore = &session.NilStore{DevAccountID: 1}
	} else {
		tokenStore = session.NewStore(rdb, session.DefaultTTL)
		slog.Info("gateway: Redis session store ready", "addr", gatewayCfg.Redis.Addr)
	}

	// Connect to NATS for inter-service event publishing.
	natsClient, natsErr := ipc.NewClient(gatewayCfg.NATS.URL)
	if natsErr != nil {
		slog.Warn("gateway: NATS unavailable — events will be discarded", "err", natsErr)
		natsClient = ipc.NewNilClient()
	}
	defer natsClient.Close()

	// Build immutable connection dependency bundles used by accept loops.
	authDeps := authConnDeps{
		rsaKP:   rsaKP,
		bfKey:   bfKeyBytes,
		db:      db,
		store:   tokenStore,
		events:  natsClient,
		servers: buildServerList(gatewayCfg),
		country: gatewayCfg.Server.Country,
	}
	gameVersion := gatewayCfg.Server.GameInternalVersion
	if gameVersion == 0 {
		gameVersion = 217 // default guess for 5.8
	}
	gameDeps := gameConnDeps{
		store:           tokenStore,
		events:          natsClient,
		internalVersion: gameVersion,
	}

	// Start auth listener (:2108).
	authLn, err := net.Listen("tcp", gatewayCfg.Server.AuthListen)
	if err != nil {
		slog.Error("gateway: listen auth port",
			"addr", gatewayCfg.Server.AuthListen, "err", err)
		os.Exit(1)
	}
	defer authLn.Close()
	slog.Info("gateway: auth listener ready", "addr", gatewayCfg.Server.AuthListen)

	// Start game listener (:7777).
	gameLn, err := net.Listen("tcp", gatewayCfg.Server.GameListen)
	if err != nil {
		slog.Error("gateway: listen game port",
			"addr", gatewayCfg.Server.GameListen, "err", err)
		os.Exit(1)
	}
	defer gameLn.Close()
	slog.Info("gateway: game listener ready", "addr", gatewayCfg.Server.GameListen)

	// Accept loops — each connection handled in its own goroutine.
	go acceptLoop(ctx, authLn, func(conn net.Conn) {
		handleAuthConn(conn, authDeps)
	})
	go acceptLoop(ctx, gameLn, func(conn net.Conn) {
		slog.Info("gateway: GAME PORT TCP ACCEPT", "addr", conn.RemoteAddr())
		handleGameConn(conn, gameDeps)
	})

	slog.Info("gateway: ready",
		"auth", gatewayCfg.Server.AuthListen,
		"game", gatewayCfg.Server.GameListen,
		"server_id", gatewayCfg.Server.ServerID,
		"max_connections", gatewayCfg.Server.MaxConnections)

	// Block until SIGTERM or SIGINT.
	waitForShutdown()
	slog.Info("gateway: shutting down")
}

// authConnDeps holds the read-only shared dependencies for the auth-port handler.
// Built once at startup and passed by value to each connection goroutine.
type authConnDeps struct {
	rsaKP   *crypto.RSAKeyPair
	bfKey   []byte
	db      *database.Pool       // nil in dev mode — verifyAccount accepts all credentials
	store   session.TokenStoreIface
	events  *ipc.Client
	servers []ServerEntry
	country int
}

// handleAuthConn manages the full auth-port (:2108) lifecycle:
//
//	SM_KEY → [CM_AUTH_LOGIN] → SM_LOGIN_OK/FAIL → [CM_PLAY] → SM_PLAY_OK
//
// On success the client receives a one-time session token and disconnects from
// this port to reconnect on the game port (:7777).
func handleAuthConn(conn net.Conn, deps authConnDeps) {
	s := newSession(conn)
	defer s.close()

	slog.Debug("gateway: auth connection", "id", s.id, "addr", conn.RemoteAddr())

	// 1. Send SM_KEY (unencrypted — BF not yet active).
	if err := s.sendSMKey(deps.rsaKP.ScrambledModulus(), deps.bfKey, deps.country); err != nil {
		slog.Warn("gateway: sendSMKey failed", "id", s.id, "err", err)
		return
	}
	s.setState(stateKeysSent)

	// Enable BF-LE encryption for all subsequent reads/writes.
	bf, err := crypto.NewBlowfishLE(deps.bfKey)
	if err != nil {
		slog.Error("gateway: BF init failed", "id", s.id, "err", err)
		return
	}
	s.bfCipher = bf

	// 2. Read first client packet — CM_AUTH_GG (0x07) or CM_AUTH_LOGIN (0x00).
	//    With -noauthgg flag the client skips GG and sends CM_AUTH_LOGIN directly.
	firstOpcode, firstPayload, err := s.readAuthPacket()
	if err != nil {
		slog.Warn("gateway: read first client packet failed", "id", s.id, "err", err)
		return
	}
	slog.Info("gateway: first client packet",
		"id", s.id,
		"opcode", fmt.Sprintf("0x%02x", firstOpcode),
		"payload_len", len(firstPayload))

	var loginPayload []byte

	switch firstOpcode {
	case byte(aionproto.CM_AUTH_GG):
		// GameGuard echo — parse session ID and respond
		var clientSessionID uint32
		if len(firstPayload) >= 4 {
			clientSessionID = binary.LittleEndian.Uint32(firstPayload[:4])
		}
		slog.Info("gateway: CM_AUTH_GG", "id", s.id, "client_session_id", clientSessionID)
		if err := s.sendSMAuthGG(clientSessionID); err != nil {
			slog.Warn("gateway: sendSMAuthGG failed", "id", s.id, "err", err)
			return
		}

		// 3. Now read CM_AUTH_LOGIN
		loginOpcode, loginPld, err := s.readAuthPacket()
		if err != nil {
			slog.Warn("gateway: read CM_AUTH_LOGIN failed", "id", s.id, "err", err)
			return
		}
		if loginOpcode != byte(aionproto.CM_AUTH_LOGIN) {
			slog.Warn("gateway: expected CM_AUTH_LOGIN after GG",
				"id", s.id, "opcode", fmt.Sprintf("0x%02x", loginOpcode))
			return
		}
		loginPayload = loginPld

	case byte(aionproto.CM_AUTH_LOGIN):
		// Direct login (client launched with -noauthgg)
		loginPayload = firstPayload

	default:
		slog.Warn("gateway: unexpected first opcode",
			"id", s.id, "opcode", fmt.Sprintf("0x%02x", firstOpcode))
		return
	}

	account, password, err := handleCMAuthLoginRaw(loginPayload, deps.rsaKP)
	if err != nil {
		slog.Warn("gateway: credential parse failed", "id", s.id, "err", err)
		_ = s.sendSMLoginFailAuth(aionproto.LoginFailInvalidCredentials)
		return
	}

	// 4. Verify credentials against the account database.
	accountID, authErr := verifyAccount(s.ctx, deps.db, account, password)
	if authErr != nil {
		slog.Info("gateway: login failed", "account", account, "reason", authErr)
		_ = s.sendSMLoginFailAuth(aionproto.LoginFailInvalidCredentials)
		return
	}

	s.account = account
	s.setState(stateAuthed)
	loginOk := int32(mrand.Uint32())
	slog.Info("gateway: login OK", "account", account, "id", s.id, "account_id", accountID)

	// 5. Send SM_LOGIN_OK (session key only, no server list).
	if err := s.sendSMLoginOKAuth(int32(accountID), loginOk); err != nil {
		slog.Warn("gateway: sendSMLoginOKAuth failed", "id", s.id, "err", err)
		return
	}

	// 6. Read CM_SERVER_LIST (0x05) — client requests server list after login OK.
	slOpcode, _, err := s.readAuthPacket()
	if err != nil {
		slog.Warn("gateway: read CM_SERVER_LIST", "id", s.id, "err", err)
		return
	}
	if slOpcode != 0x05 {
		slog.Warn("gateway: expected CM_SERVER_LIST(0x05)",
			"id", s.id, "opcode", fmt.Sprintf("0x%02x", slOpcode))
		return
	}

	// 7. Send SM_SERVER_LIST (0x04) with available game servers.
	if err := s.sendSMServerList(deps.servers); err != nil {
		slog.Warn("gateway: sendSMServerList failed", "id", s.id, "err", err)
		return
	}

	// 8. Read CM_PLAY (0x02) — server selection.
	playOpcode, playPayload, err := s.readAuthPacket()
	if err != nil {
		slog.Warn("gateway: read CM_PLAY", "id", s.id, "err", err)
		return
	}
	if playOpcode != byte(aionproto.CM_PLAY) {
		slog.Warn("gateway: expected CM_PLAY(0x02)",
			"id", s.id, "opcode", fmt.Sprintf("0x%02x", playOpcode))
		return
	}

	if len(playPayload) < 9 {
		slog.Warn("gateway: CM_PLAY payload too short", "id", s.id, "len", len(playPayload))
		return
	}
	// CM_PLAY format: accountId(4) + loginOk(4) + serverId(1)
	serverID := int(playPayload[8])

	// 9. Build NCSoft session key token: [accountId|loginOk|playOk1|playOk2].
	//    Client echoes these 16 bytes in CM_SESSION_CONFIRM on the game port.
	playOk1 := mrand.Int31()
	playOk2 := mrand.Int31()
	var sessionToken [16]byte
	binary.LittleEndian.PutUint32(sessionToken[0:4], uint32(accountID))
	binary.LittleEndian.PutUint32(sessionToken[4:8], uint32(loginOk))
	binary.LittleEndian.PutUint32(sessionToken[8:12], uint32(playOk1))
	binary.LittleEndian.PutUint32(sessionToken[12:16], uint32(playOk2))

	if err := deps.store.StoreToken(s.ctx, sessionToken, session.Data{
		AccountID: accountID,
		Account:   account,
		ServerID:  serverID,
	}); err != nil {
		slog.Error("gateway: store session token failed", "id", s.id, "err", err)
		_ = s.sendSMLoginFailAuth(aionproto.LoginFailSystemError)
		return
	}
	hexToken := fmt.Sprintf("%x", sessionToken)

	// 10. Notify World Engine about the incoming player login.
	deps.events.PublishAsync(ipc.SubjectPlayerLogin, ipc.PlayerLoginEvent{
		AccountID:  accountID,
		Account:    account,
		ServerID:   serverID,
		TokenHex:   hexToken,
		RemoteAddr: conn.RemoteAddr().String(),
	})

	// 11. Send SM_PLAY_OK — client disconnects from :2108 and connects to :7777.
	if err := s.sendSMPlayOKAuth(playOk1, playOk2, serverID); err != nil {
		slog.Warn("gateway: sendSMPlayOKAuth failed", "id", s.id, "err", err)
		return
	}

	slog.Info("gateway: auth handshake complete",
		"account", account,
		"account_id", accountID,
		"server_id", serverID)
}

// acceptLoop accepts connections from ln and dispatches each to handler.
// Returns when ctx is cancelled (listener is closed by defer in main).
func acceptLoop(ctx context.Context, ln net.Listener, handler func(net.Conn)) {
	for {
		conn, err := ln.Accept()
		if err != nil {
			select {
			case <-ctx.Done():
				return
			default:
				slog.Warn("gateway: accept error", "err", err)
				time.Sleep(10 * time.Millisecond)
				continue
			}
		}
		go handler(conn)
	}
}

// verifyAccount calls the ap_verify_account stored procedure.
// Returns the account ID on success.  When db is nil (dev mode), accepts any
// credentials and returns a fixed account ID of 1.
func verifyAccount(ctx context.Context, db *database.Pool, account, password string) (int64, error) {
	if db == nil {
		slog.Warn("gateway: DB unavailable — accepting credentials in dev mode",
			"account", account)
		return 1, nil
	}
	var accountID int64
	if err := db.CallSPRow(ctx, "ap_verify_account", account, password).Scan(&accountID); err != nil {
		return 0, err
	}
	return accountID, nil
}

// buildServerList converts gateway config into the server list sent to clients.
func buildServerList(cfg config.GatewayConfig) []ServerEntry {
	return []ServerEntry{
		{
			ID:         cfg.Server.ServerID,
			Name:       "AionCore",
			Host:       "127.0.0.1",
			Port:       7777,
			Online:     0,
			MaxPlayers: cfg.Server.MaxConnections,
		},
	}
}

// waitForShutdown blocks until SIGTERM or SIGINT is received.
func waitForShutdown() {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGTERM, syscall.SIGINT)
	<-ch
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
