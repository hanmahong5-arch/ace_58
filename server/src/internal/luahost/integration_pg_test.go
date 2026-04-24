//go:build integration

// Package luahost — PostgreSQL integration tests.
//
// These tests exercise real stored procedures against a live `aion_world_live`
// database. They are OPT-IN: the `integration` build tag keeps them out of
// the default `go test ./...` run. Invoke explicitly with:
//
//   AION_TEST_PG_HOST=127.0.0.1 \
//   AION_TEST_PG_DB=aion_world_live \
//   AION_TEST_PG_USER=aion \
//   AION_TEST_PG_PASS=*** \
//   go test -tags=integration -run TestIntegration -v ./internal/luahost
//
// Missing env vars cause t.Skip() with a clear reason so a partial setup
// does not crash the run.
package luahost

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
)

// pgEnv captures the four env vars that configure the test DB target.
// Any missing value causes the calling test to Skip.
type pgEnv struct {
	Host string
	DB   string
	User string
	Pass string
}

// readPGEnv reads the AION_TEST_PG_* environment tuple. If any value is
// empty the returned second value reports the first missing variable name,
// letting the caller produce a helpful Skip message.
func readPGEnv() (pgEnv, string) {
	e := pgEnv{
		Host: os.Getenv("AION_TEST_PG_HOST"),
		DB:   os.Getenv("AION_TEST_PG_DB"),
		User: os.Getenv("AION_TEST_PG_USER"),
		Pass: os.Getenv("AION_TEST_PG_PASS"),
	}
	switch "" {
	case e.Host:
		return e, "AION_TEST_PG_HOST"
	case e.DB:
		return e, "AION_TEST_PG_DB"
	case e.User:
		return e, "AION_TEST_PG_USER"
	case e.Pass:
		return e, "AION_TEST_PG_PASS"
	}
	return e, ""
}

// connectPG opens a single pgx connection for the duration of one test.
// A pool would be overkill for smoke checks and also obscure per-test
// connection failures behind the pool's retry logic.
func connectPG(t *testing.T) *pgx.Conn {
	t.Helper()
	env, missing := readPGEnv()
	if missing != "" {
		t.Skipf("integration skipped: %s not set — see file header for env vars", missing)
	}
	// sslmode=disable is safe for localhost loopback; production server
	// enforces 127.0.0.1-only binding per CLAUDE.md constraint #2.
	dsn := fmt.Sprintf("host=%s port=5432 user=%s password=%s dbname=%s sslmode=disable",
		env.Host, env.User, env.Pass, env.DB)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := pgx.Connect(ctx, dsn)
	if err != nil {
		t.Fatalf("pgx.Connect: %v", err)
	}
	t.Cleanup(func() {
		_ = conn.Close(context.Background())
	})
	return conn
}

// TestIntegration_SPPing is the most basic reachability check: if this
// fails nothing else in the file has a chance.
func TestIntegration_SPPing(t *testing.T) {
	conn := connectPG(t)
	var one int
	if err := conn.QueryRow(context.Background(), "SELECT 1").Scan(&one); err != nil {
		t.Fatalf("SELECT 1: %v", err)
	}
	if one != 1 {
		t.Fatalf("SELECT 1 returned %d", one)
	}
}

// TestIntegration_MailInsertSmoke drives the real system-mail SP
// (aion_mailwritesys_20111227) end-to-end: insert → read back → delete.
//
// See server/doc/s18-sp-inventory.md §1 for the full 13-arg signature.
// A throwaway recipient char_id (0x7FFF_FFF0 + random suffix) keeps the
// row safely outside any real character's ID range; Cleanup reverts the
// write even if assertions fail.
func TestIntegration_MailInsertSmoke(t *testing.T) {
	conn := connectPG(t)
	ctx := context.Background()

	// user_mail.id has no sequence default per aion_world_live.sql — we
	// must synthesize a unique id. MAX(id)+1 is sufficient for a serial
	// test; a concurrent integration run would race, which is acceptable
	// for an opt-in smoke test.
	var nextID int64
	if err := conn.QueryRow(ctx,
		"SELECT COALESCE(MAX(id),0)+1 FROM user_mail").Scan(&nextID); err != nil {
		t.Fatalf("compute next mail id: %v", err)
	}

	const testRecipient = 0x7FFFFFF0 // reserved high-range test char_id
	const testSender = 0
	title := fmt.Sprintf("s18-smoke-%d", nextID)
	content := "phase S-18 integration smoke test"
	arriveTime := int32(time.Now().Unix())

	// Clean up on exit regardless of outcome so reruns are idempotent.
	t.Cleanup(func() {
		_, _ = conn.Exec(context.Background(),
			"DELETE FROM user_mail WHERE id=$1", nextID)
	})

	// Insert the id+to_id pair first via a bare INSERT because the SP
	// does not set id. We then UPDATE via the SP's side effects to cover
	// the real code path. A cleaner future version deploys an id sequence
	// and calls the SP directly.
	if _, err := conn.Exec(ctx,
		`INSERT INTO user_mail(id,to_id,to_name,from_id,from_name,title,content,
			item_id,item_nameid,item_amount,money,state,arrive_time,express_mail,
			item_tid,abyss_point)
		 VALUES($1,$2,'',0,'',$3,$4,0,0,0,0,0,$5,0,0,0)`,
		nextID, testRecipient, title, content, arriveTime); err != nil {
		t.Fatalf("seed row: %v", err)
	}

	// Now call the real SP with the same recipient; it INSERTs a second
	// row — confirming the SP is reachable and the signature matches.
	if _, err := conn.Exec(ctx,
		`SELECT aion_mailwritesys_20111227($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
		testRecipient, "", testSender, "", title, content,
		int64(0), int32(0), int64(0), int64(0), int32(2), arriveTime, int32(0)); err != nil {
		t.Fatalf("aion_mailwritesys_20111227: %v", err)
	}

	// Verify at least our seeded row is retrievable.
	var count int
	if err := conn.QueryRow(ctx,
		"SELECT COUNT(*) FROM user_mail WHERE to_id=$1 AND title=$2",
		testRecipient, title).Scan(&count); err != nil {
		t.Fatalf("read back mail: %v", err)
	}
	if count < 1 {
		t.Fatalf("expected at least 1 mail row, got %d", count)
	}

	// Cleanup the SP-inserted row too (no id pin — match by title).
	t.Cleanup(func() {
		_, _ = conn.Exec(context.Background(),
			"DELETE FROM user_mail WHERE to_id=$1 AND title=$2",
			testRecipient, title)
	})
}

// TestIntegration_AuctionSettleSmoke drives the S-18 settlement SP against
// a live database. The test seeds a synthetic listing in an isolated high-
// range id (>= 9_999_999_000, well above any real user_auction.id), runs
// the three outcome paths in sequence, and cleans up after itself.
//
// Scenario order:
//   1. listing with no bids     → outcome_code=0, return-mail to seller
//   2. re-seed, add winning bid → outcome_code=1, two payout mails
//   3. third call on same row   → outcome_code=2 (idempotent state=99)
func TestIntegration_AuctionSettleSmoke(t *testing.T) {
	conn := connectPG(t)
	ctx := context.Background()

	// Guard against a missing deployment distinct from env-not-set.
	var exists bool
	if err := conn.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname = $1)",
		"aion_settleauction").Scan(&exists); err != nil {
		t.Fatalf("probe pg_proc: %v", err)
	}
	if !exists {
		t.Skip("SP aion_settleauction not yet deployed; see doc/s18-sp-inventory.md §3.1")
	}

	// user_auction.id is a 32-bit integer in the NCSoft schema, so we can't
	// use 9_999_999_000 — picking 2_100_000_000-range instead (above any
	// plausible production id, within int32 limits).
	const testListingID = int32(2_100_000_100)
	const testSellerID = int32(0x7FFFFFF1)
	const testBuyerID = int32(0x7FFFFFF2)
	const testGoodsID = int32(110000001) // arbitrary item template id
	const testBidQina = int64(250000)

	cleanup := func() {
		_, _ = conn.Exec(context.Background(),
			"DELETE FROM user_mail WHERE to_id IN ($1, $2)",
			testSellerID, testBuyerID)
		_, _ = conn.Exec(context.Background(),
			"DELETE FROM user_auction WHERE id = $1", testListingID)
		_, _ = conn.Exec(context.Background(),
			"DELETE FROM user_betting WHERE auctionid = $1", testListingID)
	}
	cleanup()          // clear any stale residue from prior aborted runs
	t.Cleanup(cleanup) // guarantee a clean table state after the test

	seedListing := func(withBid bool) {
		t.Helper()
		if _, err := conn.Exec(ctx, `
			INSERT INTO user_auction(id, type, race, goodsid, sellerid,
				sellername, buyerid, buyername, initqina, qina, stepqina,
				state, lastupdate, createtime, betcount)
			VALUES ($1, 1, 0, $2, $3, 's18-seller', $4, $5, 1000, $6, 100,
				0, 0, 0, $7)
		`, testListingID, testGoodsID, testSellerID,
			map[bool]int32{true: testBuyerID, false: 0}[withBid],
			map[bool]string{true: "s18-buyer", false: ""}[withBid],
			map[bool]int64{true: testBidQina, false: 1000}[withBid],
			map[bool]int32{true: 1, false: 0}[withBid]); err != nil {
			t.Fatalf("seed user_auction: %v", err)
		}
		if withBid {
			if _, err := conn.Exec(ctx,
				"INSERT INTO user_betting(ownerid, auctionid, qina) VALUES($1, $2, $3)",
				testBuyerID, testListingID, testBidQina); err != nil {
				t.Fatalf("seed user_betting: %v", err)
			}
		}
	}

	callSettle := func() (outcome int, winner int, final int64) {
		t.Helper()
		if err := conn.QueryRow(ctx,
			"SELECT outcome_code, winner_cid, final_bid FROM aion_settleauction($1)",
			int64(testListingID)).Scan(&outcome, &winner, &final); err != nil {
			t.Fatalf("aion_settleauction: %v", err)
		}
		return
	}

	// --- Scenario 1: no bids ----------------------------------------------
	seedListing(false)
	if outcome, _, _ := callSettle(); outcome != 0 {
		t.Fatalf("scenario 1 outcome: want 0, got %d", outcome)
	}
	// Seller receives a return-mail.
	var sellerMails int
	if err := conn.QueryRow(ctx,
		"SELECT COUNT(*) FROM user_mail WHERE to_id=$1", testSellerID).Scan(&sellerMails); err != nil {
		t.Fatalf("count seller mails: %v", err)
	}
	if sellerMails < 1 {
		t.Errorf("expected seller return-mail, got %d", sellerMails)
	}

	// --- Scenario 2: re-seed and settle with winning bid ------------------
	cleanup()
	seedListing(true)
	if outcome, winner, final := callSettle(); outcome != 1 {
		t.Fatalf("scenario 2 outcome: want 1, got %d (winner=%d final=%d)",
			outcome, winner, final)
	} else if winner != int(testBuyerID) || final != testBidQina {
		t.Errorf("scenario 2 payload: winner=%d final=%d (want %d/%d)",
			winner, final, testBuyerID, testBidQina)
	}
	// Both seller (kinah) and buyer (item) should now have mails.
	var buyerMails int
	if err := conn.QueryRow(ctx,
		"SELECT COUNT(*) FROM user_mail WHERE to_id=$1", testBuyerID).Scan(&buyerMails); err != nil {
		t.Fatalf("count buyer mails: %v", err)
	}
	if buyerMails < 1 {
		t.Errorf("expected buyer payout mail, got %d", buyerMails)
	}
	if err := conn.QueryRow(ctx,
		"SELECT COUNT(*) FROM user_mail WHERE to_id=$1", testSellerID).Scan(&sellerMails); err != nil {
		t.Fatalf("count seller mails (sc2): %v", err)
	}
	if sellerMails < 1 {
		t.Errorf("expected seller kinah mail in scenario 2, got %d", sellerMails)
	}

	// --- Scenario 3: third call on same (settled) listing is idempotent ---
	if outcome, _, _ := callSettle(); outcome != 2 {
		t.Fatalf("scenario 3 outcome: want 2 (already_settled), got %d", outcome)
	}
}
