package ipc

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/nats-io/nats.go"
)

// Client wraps a NATS connection with convenience publish/subscribe helpers.
// It automatically reconnects on disconnection and logs errors without panicking.
//
// A Client whose internal nc is nil acts as a silent no-op (dev mode without a
// broker). Use NewNilClient() to create one; there is no separate NilClient type.
type Client struct {
	nc  *nats.Conn
	url string
}

// NewClient connects to the NATS server at url and returns a ready Client.
// Connection options: auto-reconnect (max 10 attempts, 2s back-off), 30s ping.
func NewClient(url string) (*Client, error) {
	opts := []nats.Option{
		nats.MaxReconnects(10),
		nats.ReconnectWait(2 * time.Second),
		nats.PingInterval(30 * time.Second),
		nats.MaxPingsOutstanding(3),
		nats.DisconnectErrHandler(func(_ *nats.Conn, err error) {
			slog.Warn("nats: disconnected", "err", err)
		}),
		nats.ReconnectHandler(func(nc *nats.Conn) {
			slog.Info("nats: reconnected", "url", nc.ConnectedUrl())
		}),
		nats.ErrorHandler(func(_ *nats.Conn, _ *nats.Subscription, err error) {
			slog.Error("nats: async error", "err", err)
		}),
	}

	nc, err := nats.Connect(url, opts...)
	if err != nil {
		return nil, fmt.Errorf("nats: connect to %s: %w", url, err)
	}
	slog.Info("nats: connected", "url", url)
	return &Client{nc: nc, url: url}, nil
}

// NewNilClient returns a *Client whose operations are all silent no-ops.
// Use in dev mode when no NATS broker is available; eliminates the need for a
// separate NilClient type — all callers use *Client uniformly.
func NewNilClient() *Client {
	return &Client{nc: nil, url: "(dev-no-nats)"}
}

// Close drains and closes the NATS connection.
// Drain ensures all pending messages are flushed before closing.
// Safe to call on a nil-nc client.
func (c *Client) Close() {
	if c != nil && c.nc != nil {
		_ = c.nc.Drain()
	}
}

// Publish serialises v as JSON and publishes it to subject.
// Returns nil silently when the client is a no-op (nc == nil).
func (c *Client) Publish(subject string, v any) error {
	if c == nil || c.nc == nil {
		slog.Debug("nats: nil client — discarding publish", "subject", subject)
		return nil
	}
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("nats: marshal %T: %w", v, err)
	}
	if err := c.nc.Publish(subject, data); err != nil {
		return fmt.Errorf("nats: publish %s: %w", subject, err)
	}
	return nil
}

// PublishAsync is like Publish but does not flush; suitable for high-frequency
// gameplay events (CM_MOVE etc.) where latency matters more than guarantee.
// No-op when the client has nc == nil.
func (c *Client) PublishAsync(subject string, v any) {
	if c == nil || c.nc == nil {
		return
	}
	data, err := json.Marshal(v)
	if err != nil {
		slog.Error("nats: marshal for async publish", "subject", subject, "err", err)
		return
	}
	if err := c.nc.Publish(subject, data); err != nil {
		slog.Error("nats: async publish", "subject", subject, "err", err)
	}
}

// Subscribe registers an async JSON subscriber.  The callback fn receives a
// decoded value of type T for each message.  Returns a function to cancel the
// subscription.
//
// When the client is a no-op (nc == nil), returns a no-op unsub and nil error
// so callers need no special-casing for dev mode.
func Subscribe[T any](c *Client, subject string, fn func(T)) (func(), error) {
	if c == nil || c.nc == nil {
		return func() {}, nil
	}
	sub, err := c.nc.Subscribe(subject, func(msg *nats.Msg) {
		var v T
		if err := json.Unmarshal(msg.Data, &v); err != nil {
			slog.Warn("nats: unmarshal failed", "subject", subject, "err", err)
			return
		}
		fn(v)
	})
	if err != nil {
		return nil, fmt.Errorf("nats: subscribe %s: %w", subject, err)
	}
	return func() { _ = sub.Unsubscribe() }, nil
}

// Request sends a JSON-encoded request and waits for a JSON-decoded reply.
// Used for synchronous World ↔ Gateway exchanges (e.g., character list fetch).
// Returns an error immediately when the client is a no-op.
func Request[Req, Resp any](ctx context.Context, c *Client, subject string, req Req) (Resp, error) {
	var zero Resp
	if c == nil || c.nc == nil {
		return zero, fmt.Errorf("nats: not connected (dev mode)")
	}
	data, err := json.Marshal(req)
	if err != nil {
		return zero, fmt.Errorf("nats: marshal request: %w", err)
	}

	deadline, ok := ctx.Deadline()
	timeout := 5 * time.Second
	if ok {
		timeout = time.Until(deadline)
	}

	msg, err := c.nc.Request(subject, data, timeout)
	if err != nil {
		return zero, fmt.Errorf("nats: request %s: %w", subject, err)
	}

	var resp Resp
	if err := json.Unmarshal(msg.Data, &resp); err != nil {
		return zero, fmt.Errorf("nats: unmarshal response: %w", err)
	}
	return resp, nil
}

// IsConnected returns true if the NATS connection is currently active.
func (c *Client) IsConnected() bool {
	return c != nil && c.nc != nil && c.nc.IsConnected()
}
