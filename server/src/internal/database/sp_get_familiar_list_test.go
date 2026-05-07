// Package database — integration test for aion_GetFamiliarList.
//
// Returns 17-column familiar snapshot for char_id where deleted != 1.
// Test matrix:
//   - owner with 2 active + 1 deleted familiar → returns the 2 actives
//   - owner with no familiars → 0 rows
//   - column projection survives round-trip with non-default values
package database

import (
	"context"
	"sort"
	"testing"
	"time"
)

const (
	cidFamilOwnerA = 9001800
	cidFamilOwnerB = 9001801
	cidFamilEmpty  = 9001802
)

func getFamiliarListCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_familiar WHERE char_id BETWEEN 9001800 AND 9001899`); err != nil {
		t.Fatalf("getFamiliarListCleanup familiar: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_data WHERE char_id BETWEEN 9001800 AND 9001899`); err != nil {
		t.Fatalf("getFamiliarListCleanup user_data: %v", err)
	}
}

func TestGetFamiliarList(t *testing.T) {
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

	getFamiliarListCleanup(t, ctx, pool)
	t.Cleanup(func() { getFamiliarListCleanup(t, context.Background(), pool) })

	for _, seed := range []struct {
		id   int
		name string
	}{
		{cidFamilOwnerA, "FamOwnerA"},
		{cidFamilOwnerB, "FamOwnerB"},
		{cidFamilEmpty, "FamEmpty"},
	} {
		if _, err := pool.Inner().Exec(ctx,
			`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)`,
			seed.id, seed.name, "fl_"+seed.name); err != nil {
			t.Fatalf("seed %s: %v", seed.name, err)
		}
	}

	// OwnerA: 2 actives + 1 deleted.
	insertFam := func(charID int, name string, baseNameID, curNameID, evolveCnt int, deleted int) int64 {
		t.Helper()
		var id int64
		if err := pool.Inner().QueryRow(ctx,
			`INSERT INTO user_familiar(char_id, name, base_name_id, cur_name_id, evolve_cnt,
			                           create_time, update_time, safety_flag, growth_point,
			                           slot1, slot2, slot3, slot4, slot5, slot6, looting_state, deleted)
			 VALUES ($1, $2, $3, $4, $5, 1700000000000, 1700000001000, 0, 100,
			         101, 102, 103, 104, 105, 106, 1, $6) RETURNING id`,
			charID, name, baseNameID, curNameID, evolveCnt, deleted).Scan(&id); err != nil {
			t.Fatalf("insertFam %s: %v", name, err)
		}
		return id
	}
	idActive1 := insertFam(cidFamilOwnerA, "Pebble", 700001, 700002, 1, 0)
	idActive2 := insertFam(cidFamilOwnerA, "Cinder", 700003, 700004, 0, 0)
	_ = insertFam(cidFamilOwnerA, "Ghost", 700005, 700006, 0, 1) // soft-deleted

	t.Run("owner with mixed familiars returns only actives", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getfamiliarlist", cidFamilOwnerA)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()

		var (
			gotIDs []int64
			row    struct {
				id            int64
				charID        int32
				baseNameID    int32
				curNameID     int32
				name          string
				evolveCnt     int32
				createTime    int64
				updateTime    int64
				safetyFlag    int16
				growthPoint   int32
				s1, s2, s3, s4, s5, s6 int32
				lootingState  int16
			}
			lastName string
		)
		for rows.Next() {
			if err := rows.Scan(
				&row.id, &row.charID, &row.baseNameID, &row.curNameID, &row.name,
				&row.evolveCnt, &row.createTime, &row.updateTime,
				&row.safetyFlag, &row.growthPoint,
				&row.s1, &row.s2, &row.s3, &row.s4, &row.s5, &row.s6,
				&row.lootingState,
			); err != nil {
				t.Fatalf("Scan: %v", err)
			}
			gotIDs = append(gotIDs, row.id)
			lastName = row.name
			// Spot-check column round-trip on whichever row scanned last.
			if row.charID != int32(cidFamilOwnerA) {
				t.Fatalf("char_id projection: got %d, want %d", row.charID, cidFamilOwnerA)
			}
			if row.s1 != 101 || row.s6 != 106 {
				t.Fatalf("slot projection: s1=%d s6=%d, want 101/106", row.s1, row.s6)
			}
			if row.growthPoint != 100 || row.lootingState != 1 {
				t.Fatalf("scalar projection: growth_point=%d looting_state=%d, want 100/1",
					row.growthPoint, row.lootingState)
			}
		}
		_ = lastName

		sort.Slice(gotIDs, func(i, j int) bool { return gotIDs[i] < gotIDs[j] })
		want := []int64{idActive1, idActive2}
		sort.Slice(want, func(i, j int) bool { return want[i] < want[j] })
		if len(gotIDs) != 2 || gotIDs[0] != want[0] || gotIDs[1] != want[1] {
			t.Fatalf("active ids: got %v, want %v (deleted=1 must be filtered)", gotIDs, want)
		}
	})

	t.Run("char with no familiars returns 0 rows", func(t *testing.T) {
		rows, err := pool.CallSP(ctx, "aion_getfamiliarlist", cidFamilEmpty)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("empty owner: got %d rows, want 0", n)
		}
	})

	t.Run("char with only deleted familiars returns 0 rows", func(t *testing.T) {
		// OwnerB: insert one deleted-only familiar.
		_ = insertFam(cidFamilOwnerB, "GoneFamiliar", 700007, 700008, 0, 1)
		rows, err := pool.CallSP(ctx, "aion_getfamiliarlist", cidFamilOwnerB)
		if err != nil {
			t.Fatalf("CallSP: %v", err)
		}
		defer rows.Close()
		var n int
		for rows.Next() {
			n++
		}
		if n != 0 {
			t.Fatalf("deleted-only: got %d rows, want 0", n)
		}
	})
}
