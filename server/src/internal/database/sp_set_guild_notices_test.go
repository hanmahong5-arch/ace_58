// Package database — integration test for aion_SetGuildNotices.
//
// Pure UPDATE on the guild row, writing all 7 notice slots + 7 epoch
// timestamps in one shot. Bug-for-bug NCSoft: no existence guard.
//
// Test matrix:
//   - happy path: existing guild → 1 row, all 14 cols persisted
//   - empty strings + 0 timestamps → all written verbatim
//   - missing guild: 0 rows (silent no-op)
//   - neighbour isolation: A's notices do NOT leak into B
package database

import (
	"context"
	"testing"
	"time"
)

const (
	gidNoticesA       = 9430001
	gidNoticesB       = 9430002
	gidNoticesMissing = 9430099
)

// notice7 is a tuple of (time, text) for compact iteration in assertions.
type guildNoticeSlot struct {
	t    int32
	text string
}

func setGuildNoticesCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM guild WHERE id BETWEEN 9430001 AND 9430099`); err != nil {
		t.Fatalf("setGuildNoticesCleanup guild: %v", err)
	}
}

func readGuildNotices(t *testing.T, ctx context.Context, p *Pool, gid int) [7]guildNoticeSlot {
	t.Helper()
	var (
		t1, t2, t3, t4, t5, t6, t7 int32
		s1, s2, s3, s4, s5, s6, s7 string
	)
	if err := p.Inner().QueryRow(ctx,
		`SELECT noticetime1, notice1, noticetime2, notice2,
		        noticetime3, notice3, noticetime4, notice4,
		        noticetime5, notice5, noticetime6, notice6,
		        noticetime7, notice7
		   FROM guild WHERE id = $1`, gid).Scan(
		&t1, &s1, &t2, &s2, &t3, &s3, &t4, &s4,
		&t5, &s5, &t6, &s6, &t7, &s7); err != nil {
		t.Fatalf("readGuildNotices %d: %v", gid, err)
	}
	return [7]guildNoticeSlot{
		{t1, s1}, {t2, s2}, {t3, s3}, {t4, s4},
		{t5, s5}, {t6, s6}, {t7, s7},
	}
}

func TestSetGuildNotices(t *testing.T) {
	dsn, reason := testDSN()
	if reason != "" {
		t.Skipf("integration skipped: %s", reason)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	setGuildNoticesCleanup(t, ctx, pool)
	t.Cleanup(func() { setGuildNoticesCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{gidNoticesA, "NoticeLegionA"},
		{gidNoticesB, "NoticeLegionB"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO guild(id, name) VALUES ($1, $2)`,
			seed.id, seed.name); err != nil {
			t.Fatalf("seed guild %d: %v", seed.id, err)
		}
	}

	t.Run("happy path: 7 distinct slots persisted", func(t *testing.T) {
		// Pin every value so a future column-shuffle bug surfaces immediately.
		want := [7]guildNoticeSlot{
			{1700000001, "Welcome to NoticeLegionA!"},
			{1700000002, "Raid Friday 9pm"},
			{1700000003, "Recruiting healers"},
			{1700000004, "Be respectful"},
			{1700000005, "Discord: example.com/legion"},
			{1700000006, "Donations: optional"},
			{1700000007, "Master is on holiday"},
		}
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildnotices",
			gidNoticesA,
			want[0].t, want[0].text,
			want[1].t, want[1].text,
			want[2].t, want[2].text,
			want[3].t, want[3].text,
			want[4].t, want[4].text,
			want[5].t, want[5].text,
			want[6].t, want[6].text,
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow: %v", err)
		}
		if affected != 1 {
			t.Fatalf("happy: got %d, want 1", affected)
		}

		got := readGuildNotices(t, ctx, pool, gidNoticesA)
		for i := 0; i < 7; i++ {
			if got[i] != want[i] {
				t.Fatalf("slot %d: got %+v, want %+v", i+1, got[i], want[i])
			}
		}
	})

	t.Run("empty strings + zero timestamps overwrite cleanly", func(t *testing.T) {
		// /legion notice clear sends all-empty in NCSoft. We must persist
		// the empty state — not silently keep prior values.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildnotices",
			gidNoticesA,
			int32(0), "",
			int32(0), "",
			int32(0), "",
			int32(0), "",
			int32(0), "",
			int32(0), "",
			int32(0), "",
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow clear: %v", err)
		}
		if affected != 1 {
			t.Fatalf("clear: got %d, want 1", affected)
		}

		got := readGuildNotices(t, ctx, pool, gidNoticesA)
		for i := 0; i < 7; i++ {
			if got[i].t != 0 || got[i].text != "" {
				t.Fatalf("slot %d not cleared: got %+v", i+1, got[i])
			}
		}
	})

	t.Run("missing guild → 0 rows (silent no-op)", func(t *testing.T) {
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildnotices",
			gidNoticesMissing,
			int32(1), "x",
			int32(2), "x",
			int32(3), "x",
			int32(4), "x",
			int32(5), "x",
			int32(6), "x",
			int32(7), "x",
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow missing: %v", err)
		}
		if affected != 0 {
			t.Fatalf("missing guild: got %d, want 0", affected)
		}
	})

	t.Run("neighbour isolation: B's notices remain default after A's churn", func(t *testing.T) {
		// Touch A again with a fresh batch; B must remain at scaffold defaults.
		var affected int
		if err := pool.CallSPRow(ctx, "aion_setguildnotices",
			gidNoticesA,
			int32(2000000001), "fresh1",
			int32(2000000002), "fresh2",
			int32(2000000003), "fresh3",
			int32(2000000004), "fresh4",
			int32(2000000005), "fresh5",
			int32(2000000006), "fresh6",
			int32(2000000007), "fresh7",
		).Scan(&affected); err != nil {
			t.Fatalf("CallSPRow A perturb: %v", err)
		}
		if affected != 1 {
			t.Fatalf("A perturb: got %d, want 1", affected)
		}

		got := readGuildNotices(t, ctx, pool, gidNoticesB)
		for i := 0; i < 7; i++ {
			if got[i].t != 0 || got[i].text != "" {
				t.Fatalf("B slot %d leaked from A: got %+v", i+1, got[i])
			}
		}
	})
}
