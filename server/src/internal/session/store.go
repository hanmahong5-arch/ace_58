// Package session manages short-lived session tokens used during the AION
// login → game handshake.
//
// Flow:
//   1. Auth port (:2108) issues a token after CM_PLAY is accepted.
//   2. Token is stored in Redis with a short TTL (default 60 s).
//   3. Game port (:7777) verifies the token in CM_SESSION_CONFIRM.
//   4. Token is deleted after first use (one-time use).
//
// Tokens are 16 bytes of cryptographically random data, hex-encoded to 32 chars.
package session

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

const (
	// DefaultTTL is the time a session token remains valid.
	// 60 seconds is generous — the client typically reconnects within 5 seconds.
	DefaultTTL = 60 * time.Second

	// keyPrefix is the Redis key namespace for session tokens.
	keyPrefix = "aion:session:"
)

// Data is the payload stored alongside a session token in Redis.
type Data struct {
	AccountID int64  `json:"account_id"`
	Account   string `json:"account"`
	ServerID  int    `json:"server_id"`
}

// Store is a Redis-backed one-time-use session token store.
type Store struct {
	rdb *redis.Client
	ttl time.Duration
}

// NewStore creates a Store backed by the given Redis client.
// Use DefaultTTL for ttl unless a shorter window is required.
func NewStore(rdb *redis.Client, ttl time.Duration) *Store {
	if ttl <= 0 {
		ttl = DefaultTTL
	}
	return &Store{rdb: rdb, ttl: ttl}
}

// Issue generates a cryptographically random token, stores data in Redis,
// and returns the token as a 32-char hex string.
func (s *Store) Issue(ctx context.Context, data Data) (string, error) {
	var raw [16]byte
	if _, err := rand.Read(raw[:]); err != nil {
		return "", fmt.Errorf("session: token generation failed: %w", err)
	}
	token := hex.EncodeToString(raw[:])

	payload, err := json.Marshal(data)
	if err != nil {
		return "", fmt.Errorf("session: marshal failed: %w", err)
	}

	key := keyPrefix + token
	if err := s.rdb.Set(ctx, key, payload, s.ttl).Err(); err != nil {
		return "", fmt.Errorf("session: redis SET failed: %w", err)
	}
	return token, nil
}

// Verify retrieves and atomically deletes the token from Redis.
// Returns ErrTokenNotFound if the token does not exist or has expired.
// One-time-use: calling Verify twice with the same token always fails on the second call.
func (s *Store) Verify(ctx context.Context, token string) (Data, error) {
	key := keyPrefix + token

	// Atomic GET + DEL via pipeline to ensure one-time-use even under concurrency.
	var getCmd *redis.StringCmd
	_, err := s.rdb.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
		getCmd = pipe.Get(ctx, key)
		pipe.Del(ctx, key)
		return nil
	})
	if err != nil && err != redis.Nil {
		return Data{}, fmt.Errorf("session: redis pipeline failed: %w", err)
	}

	payload, err := getCmd.Bytes()
	if err == redis.Nil {
		return Data{}, ErrTokenNotFound
	}
	if err != nil {
		return Data{}, fmt.Errorf("session: redis GET failed: %w", err)
	}

	var data Data
	if err := json.Unmarshal(payload, &data); err != nil {
		return Data{}, fmt.Errorf("session: unmarshal failed: %w", err)
	}
	return data, nil
}

// IssueRaw is like Issue but returns the raw 16-byte token (for packet transmission).
// The token bytes are what go into SM_PLAY_OK; the hex form is the Redis key.
func (s *Store) IssueRaw(ctx context.Context, data Data) (rawToken [16]byte, hexToken string, err error) {
	if _, err := rand.Read(rawToken[:]); err != nil {
		return rawToken, "", fmt.Errorf("session: token generation failed: %w", err)
	}
	hexToken = hex.EncodeToString(rawToken[:])

	payload, err := json.Marshal(data)
	if err != nil {
		return rawToken, "", fmt.Errorf("session: marshal failed: %w", err)
	}

	key := keyPrefix + hexToken
	if err := s.rdb.Set(ctx, key, payload, s.ttl).Err(); err != nil {
		return rawToken, "", fmt.Errorf("session: redis SET failed: %w", err)
	}
	return rawToken, hexToken, nil
}

// VerifyRaw looks up a token given as raw bytes (from CM_SESSION_CONFIRM).
func (s *Store) VerifyRaw(ctx context.Context, rawToken []byte) (Data, error) {
	return s.Verify(ctx, hex.EncodeToString(rawToken))
}

// ErrTokenNotFound is returned when a token is absent or expired.
var ErrTokenNotFound = fmt.Errorf("session: token not found or expired")

// NilStore is a Store that accepts any token — used in dev mode when Redis is unavailable.
// It always returns a fixed Data so local testing works without Redis.
type NilStore struct {
	DevAccountID int64
}

// IssueRaw returns a fixed dev token.
func (n *NilStore) IssueRaw(_ context.Context, data Data) (rawToken [16]byte, hexToken string, err error) {
	copy(rawToken[:], "dev-token-1234567")
	return rawToken, hex.EncodeToString(rawToken[:]), nil
}

// VerifyRaw always succeeds with the dev account ID.
func (n *NilStore) VerifyRaw(_ context.Context, _ []byte) (Data, error) {
	return Data{AccountID: n.DevAccountID, Account: "dev", ServerID: 10}, nil
}

// TokenStoreIface is the interface used by the gateway so the real and nil stores
// are interchangeable.
type TokenStoreIface interface {
	IssueRaw(ctx context.Context, data Data) (rawToken [16]byte, hexToken string, err error)
	VerifyRaw(ctx context.Context, rawToken []byte) (Data, error)
}
