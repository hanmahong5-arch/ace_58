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
	"encoding/hex"
	"log/slog"
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
	db, err = database.NewPool(ctx, gatewayCfg.Database.DSN())
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
	gameDeps := gameConnDeps{
		store:  tokenStore,
		events: natsClient,
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
	if err := s.sendSMKey(deps.rsaKP.PublicKeyModulus(), deps.bfKey, deps.country); err != nil {
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

	// 2. Read CM_AUTH_LOGIN.
	pkt, err := s.readPacket()
	if err != nil {
		slog.Warn("gateway: read CM_AUTH_LOGIN", "id", s.id, "err", err)
		return
	}
	if pkt.Opcode() != aionproto.CM_AUTH_LOGIN {
		slog.Warn("gateway: unexpected opcode after SM_KEY",
			"id", s.id, "opcode", pkt.Opcode())
		return
	}

	account, password, err := s.handleCMAuthLogin(pkt, deps.rsaKP)
	if err != nil {
		slog.Warn("gateway: credential parse failed", "id", s.id, "err", err)
		_ = s.sendSMLoginFail(aionproto.LoginFailInvalidCredentials)
		return
	}

	// 3. Verify credentials against the account database.
	accountID, authErr := verifyAccount(s.ctx, deps.db, account, password)
	if authErr != nil {
		slog.Info("gateway: login failed", "account", account, "reason", authErr)
		_ = s.sendSMLoginFail(aionproto.LoginFailInvalidCredentials)
		return
	}

	s.account = account
	s.setState(stateAuthed)
	slog.Info("gateway: login OK", "account", account, "id", s.id, "account_id", accountID)

	// 4. Send SM_LOGIN_OK with server list.
	if err := s.sendSMLoginOK(accountID, deps.servers); err != nil {
		slog.Warn("gateway: sendSMLoginOK failed", "id", s.id, "err", err)
		return
	}

	// 5. Read CM_PLAY (server selection).
	pkt, err = s.readPacket()
	if err != nil {
		slog.Warn("gateway: read CM_PLAY", "id", s.id, "err", err)
		return
	}
	if pkt.Opcode() != aionproto.CM_PLAY {
		slog.Warn("gateway: unexpected opcode after SM_LOGIN_OK",
			"id", s.id, "opcode", pkt.Opcode())
		return
	}

	serverID, _ := pkt.ReadUint32()

	// 6. Issue a cryptographically random one-time session token.
	//    Redis stores it with a 60s TTL; the game port verifies and deletes it
	//    atomically on CM_SESSION_CONFIRM (prevents replay attacks).
	rawToken, hexToken, err := deps.store.IssueRaw(s.ctx, session.Data{
		AccountID: accountID,
		Account:   account,
		ServerID:  int(serverID),
	})
	if err != nil {
		slog.Error("gateway: issue session token failed", "id", s.id, "err", err)
		_ = s.sendSMLoginFail(aionproto.LoginFailSystemError)
		return
	}

	// 7. Notify World Engine about the incoming player login.
	//    World stores the session state and waits for player.enter from the game port.
	deps.events.PublishAsync(ipc.SubjectPlayerLogin, ipc.PlayerLoginEvent{
		AccountID:  accountID,
		Account:    account,
		ServerID:   int(serverID),
		TokenHex:   hexToken,
		RemoteAddr: conn.RemoteAddr().String(),
	})

	// 8. Send SM_PLAY_OK — client disconnects from :2108 and connects to :7777.
	if err := s.sendSMPlayOK(int(serverID), rawToken[:]); err != nil {
		slog.Warn("gateway: sendSMPlayOK failed", "id", s.id, "err", err)
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
