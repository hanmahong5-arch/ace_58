//go:build nats

// Opt-in NATS end-to-end smoke test.
//
// Runs only when compiled with `-tags nats`. Expects an external broker at
// nats://127.0.0.1:4222 (install via `go install github.com/nats-io/nats-server/v2@latest`
// and run `nats-server` in another terminal). If the broker is unreachable,
// tests are skipped rather than failed — default CI stays green.
//
// Run:  go test -tags nats ./internal/ipc/ -run NATSSmoke -v
package ipc

import (
	"context"
	"encoding/json"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/nats-io/nats.go"
)

// testNATSURL is the broker endpoint the smoke tests probe. Override via env
// NATS_URL if your local nats-server listens elsewhere.
const testNATSURL = nats.DefaultURL // nats://127.0.0.1:4222

// dialOrSkip tries a short-deadline connection so absent broker → t.Skip (not Fatal).
func dialOrSkip(t *testing.T) *Client {
	t.Helper()
	nc, err := nats.Connect(testNATSURL,
		nats.Timeout(500*time.Millisecond),
		nats.MaxReconnects(0),
	)
	if err != nil {
		t.Skipf("NATS broker not reachable at %s (%v); start `nats-server` to enable", testNATSURL, err)
	}
	return &Client{nc: nc, url: testNATSURL}
}

// TestNATSSmokePublishSubscribeRoundtrip proves one producer → one consumer
// round-trip using PlayerEnterEvent (the only event with a wired subscriber
// that is production-critical).
func TestNATSSmokePublishSubscribeRoundtrip(t *testing.T) {
	c := dialOrSkip(t)
	defer c.Close()

	recv := make(chan PlayerEnterEvent, 1)
	unsub, err := Subscribe[PlayerEnterEvent](c, SubjectPlayerEnter, func(ev PlayerEnterEvent) {
		// Drop-on-full so a slow test goroutine cannot block the NATS dispatcher.
		select {
		case recv <- ev:
		default:
		}
	})
	if err != nil {
		t.Fatalf("subscribe: %v", err)
	}
	defer unsub()

	// nats.go queues the SUB protocol frame; flush ensures the server has
	// registered our interest before the publisher fires.
	if err := c.nc.Flush(); err != nil {
		t.Fatalf("flush: %v", err)
	}

	want := PlayerEnterEvent{
		AccountID:    42,
		Account:      "smoke",
		GatewaySeqID: 0xDEADBEEF,
		RemoteAddr:   "127.0.0.1:65432",
	}
	if err := c.Publish(SubjectPlayerEnter, want); err != nil {
		t.Fatalf("publish: %v", err)
	}

	select {
	case got := <-recv:
		if got != want {
			t.Fatalf("payload mismatch: got %+v want %+v", got, want)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timeout waiting for PlayerEnterEvent round-trip")
	}
}

// TestNATSSmokeJetStreamDurableSubscriber exercises JetStream durable consumer
// semantics. ipc/nats.go currently uses core NATS only — see
// doc/s18-nats-inventory.md §6 — so this test skips. Kept as a placeholder so
// a future JetStream migration has an obvious failing test to make pass.
func TestNATSSmokeJetStreamDurableSubscriber(t *testing.T) {
	t.Skip("JetStream not used by internal/ipc/nats.go as of S-18; core NATS only")
}

// TestNATSSmokeMultiSubscriberFanout validates that our subscriber fan-out
// semantics match production (World subscribes once to player.enter; multiple
// subscribers must each receive every message). Guards against a future
// accidental switch to queue groups.
func TestNATSSmokeMultiSubscriberFanout(t *testing.T) {
	c := dialOrSkip(t)
	defer c.Close()

	const subject = "smoke.fanout"
	const subscribers = 3
	const messages = 5

	var received [subscribers]atomic.Int32
	wg := &sync.WaitGroup{}
	wg.Add(subscribers * messages)

	for i := 0; i < subscribers; i++ {
		idx := i
		unsub, err := Subscribe[PacketEvent](c, subject, func(ev PacketEvent) {
			received[idx].Add(1)
			wg.Done()
		})
		if err != nil {
			t.Fatalf("subscribe %d: %v", idx, err)
		}
		defer unsub()
	}
	if err := c.nc.Flush(); err != nil {
		t.Fatalf("flush: %v", err)
	}

	for i := 0; i < messages; i++ {
		if err := c.Publish(subject, PacketEvent{Opcode: uint16(i)}); err != nil {
			t.Fatalf("publish %d: %v", i, err)
		}
	}

	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		for i := range received {
			t.Logf("subscriber %d received %d/%d", i, received[i].Load(), messages)
		}
		t.Fatal("timeout waiting for fanout")
	}

	for i := range received {
		if got := received[i].Load(); got != messages {
			t.Errorf("subscriber %d: got %d, want %d", i, got, messages)
		}
	}
}

// TestNATSSmokeRequestReply exercises the generic Request[Req,Resp] helper
// used for synchronous World↔Gateway exchanges. A responder goroutine echoes
// the request payload back; the requester verifies round-trip correctness.
func TestNATSSmokeRequestReply(t *testing.T) {
	c := dialOrSkip(t)
	defer c.Close()

	const subject = "smoke.req"

	// Responder: subscribe to subject, reply with a WorldEnterAckEvent.
	sub, err := c.nc.Subscribe(subject, func(msg *nats.Msg) {
		ack := WorldEnterAckEvent{GatewaySeqID: 777, Status: "ok", Message: "pong"}
		data, _ := json.Marshal(ack)
		_ = msg.Respond(data)
	})
	if err != nil {
		t.Fatalf("responder subscribe: %v", err)
	}
	defer func() { _ = sub.Unsubscribe() }()
	if err := c.nc.Flush(); err != nil {
		t.Fatalf("flush: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	resp, err := Request[PlayerEnterEvent, WorldEnterAckEvent](ctx, c, subject, PlayerEnterEvent{GatewaySeqID: 777})
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	if resp.GatewaySeqID != 777 || resp.Status != "ok" {
		t.Fatalf("unexpected reply: %+v", resp)
	}
}
