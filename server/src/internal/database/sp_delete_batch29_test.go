// Package database — integration test for batch 29 (Client-data cleanup +
// single-row abnormal):
//
//   00286 aion_DeleteAbnormalStatus(char_id, abnormal_id)
//   00287 aion_DeleteChallengeTask(task_db_id)               -- 3-table cascade
//   00288 aion_DeleteClientSettings(char_id)
//   00289 aion_DeleteClientQuickBar(char_id)
//   00290 aion_DeleteClientfavorite(char_id)
//
// All five widen NCSoft VOID → INTEGER rows-affected. Tests exercise:
//   - happy-path delete with seeded rows
//   - idempotent re-delete returns 0
//   - per-key vs whole-key isolation (00286 single row, others wipe-all)
//   - 00287 cascade sum across 3 tables
//
// char_id band: 9_740_001 .. 9_740_099  (distinct from batch-28's 9_720 band
// and batch-27's 9_710 band — per engineering-swarm "SP migration burst"
// file-lock convention).
//
// Skip-if-no-DSN: when AION_TEST_PG_* env tuple is missing the suite is
// t.Skip()ped — keeps `go test ./...` clean for contributors without a
// local PG.
package database

import (
	"context"
	"testing"
	"time"
)

// Sentinel char_ids for batch-29 fixture range.
const (
	cidDel29AbnA      = 9740001 // abnormal-status target
	cidDel29AbnEmpty  = 9740002 // user_data exists, no abnormal rows
	cidDel29SettingsA = 9740010 // client_settings wipe target
	cidDel29QuickbarA = 9740011 // client_quickbar wipe target
	cidDel29FavoriteA = 9740012 // client_favorite wipe target
	cidDel29ControlX  = 9740099 // neighbour control — must NOT be touched
)

// Sentinel skill_ids / abnormal_ids and challenge_task ids — all in the
// 9_740_xxx numeric range to avoid colliding with production data.
//
// user_abnormal_status has TWO disambiguating columns: abnormal_id (PK with
// char_id) and skill_id (own UNIQUE with char_id). Seed rows must vary BOTH
// to avoid PK / UNIQUE collisions; the SP filters on skill_id (per NCSoft).
const (
	del29SkillIDA    = 9740101 // exists, target of single-skill delete
	del29SkillIDB    = 9740102 // exists, control (must survive)
	del29SkillIDX    = 9740103 // never seeded — non-existent path
	del29AbnormalIDA = 9740111 // PK partner for SkillIDA
	del29AbnormalIDB = 9740112 // PK partner for SkillIDB

	del29TaskA = int64(9740201) // 3-table-cascade target
	del29TaskB = int64(9740202) // partial-presence (only side tables)
	del29TaskX = int64(9740299) // never seeded
)

// deleteBatch29Cleanup scrubs every fixture artefact this test owns.
func deleteBatch29Cleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()

	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_abnormal_status WHERE char_id BETWEEN 9740001 AND 9740099`); err != nil {
		t.Fatalf("cleanup user_abnormal_status: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_settings WHERE char_id BETWEEN 9740001 AND 9740099`); err != nil {
		t.Fatalf("cleanup user_client_settings: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_quickbar WHERE char_id BETWEEN 9740001 AND 9740099`); err != nil {
		t.Fatalf("cleanup user_client_quickbar: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM user_client_favorite WHERE char_id BETWEEN 9740001 AND 9740099`); err != nil {
		t.Fatalf("cleanup user_client_favorite: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM challenge_task             WHERE id                BETWEEN 9740200 AND 9740299`); err != nil {
		t.Fatalf("cleanup challenge_task: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM challenge_task_quest       WHERE challenge_task_id BETWEEN 9740200 AND 9740299`); err != nil {
		t.Fatalf("cleanup challenge_task_quest: %v", err)
	}
	if _, err := p.Inner().Exec(ctx,
		`DELETE FROM challenge_task_contributor WHERE challenge_task_id BETWEEN 9740200 AND 9740299`); err != nil {
		t.Fatalf("cleanup challenge_task_contributor: %v", err)
	}
}

// TestSPDeleteBatch29 — cohort entry-point. Each sub-test is one SP.
func TestSPDeleteBatch29(t *testing.T) {
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

	deleteBatch29Cleanup(t, ctx, pool)
	t.Cleanup(func() { deleteBatch29Cleanup(t, context.Background(), pool) })

	mustExec := func(sql string, args ...any) {
		t.Helper()
		if _, err := pool.Inner().Exec(ctx, sql, args...); err != nil {
			t.Fatalf("seed (%s): %v", sql, err)
		}
	}
	assertCount := func(label, sql string, args []any, want int) {
		t.Helper()
		var got int
		if err := pool.Inner().QueryRow(ctx, sql, args...).Scan(&got); err != nil {
			t.Fatalf("count %s: %v", label, err)
		}
		if got != want {
			t.Fatalf("count %s: got %d, want %d", label, got, want)
		}
	}

	// --------- 00286 aion_deleteabnormalstatus (single-row by (char_id, skill_id)) ---------
	t.Run("00286_DeleteAbnormalStatus", func(t *testing.T) {
		// Seed two rows on A — distinct abnormal_id (PK partner) AND distinct
		// skill_id (UNIQUE partner). Both axes must differ.
		mustExec(`INSERT INTO user_abnormal_status
			(char_id, abnormal_id, remain_time_ms, skill_id) VALUES ($1, $2, $3, $4)`,
			cidDel29AbnA, del29AbnormalIDA, 60000, del29SkillIDA)
		mustExec(`INSERT INTO user_abnormal_status
			(char_id, abnormal_id, remain_time_ms, skill_id) VALUES ($1, $2, $3, $4)`,
			cidDel29AbnA, del29AbnormalIDB, 60000, del29SkillIDB)

		// Happy path: delete (A, skill=SkillIDA) → 1.
		var aff int
		if err := pool.CallSPRow(ctx, "aion_deleteabnormalstatus",
			int(cidDel29AbnA), int(del29SkillIDA)).Scan(&aff); err != nil {
			t.Fatalf("CallSPRow A,SkillIDA: %v", err)
		}
		if aff != 1 {
			t.Fatalf("delete A,SkillIDA: got %d, want 1", aff)
		}

		// Sibling row (A, skill=SkillIDB) untouched — per-skill scope.
		assertCount("A,SkillIDB survives",
			`SELECT COUNT(*) FROM user_abnormal_status WHERE char_id=$1 AND skill_id=$2`,
			[]any{cidDel29AbnA, del29SkillIDB}, 1)

		// Non-existent skill_id → 0 silently.
		var aff2 int
		if err := pool.CallSPRow(ctx, "aion_deleteabnormalstatus",
			int(cidDel29AbnA), int(del29SkillIDX)).Scan(&aff2); err != nil {
			t.Fatalf("CallSPRow A,SkillIDX: %v", err)
		}
		if aff2 != 0 {
			t.Fatalf("missing: got %d, want 0", aff2)
		}

		// Empty char → 0 silently.
		var aff3 int
		if err := pool.CallSPRow(ctx, "aion_deleteabnormalstatus",
			int(cidDel29AbnEmpty), int(del29SkillIDA)).Scan(&aff3); err != nil {
			t.Fatalf("CallSPRow empty char: %v", err)
		}
		if aff3 != 0 {
			t.Fatalf("empty: got %d, want 0", aff3)
		}

		// Idempotent re-delete on the already-deleted row.
		var aff4 int
		if err := pool.CallSPRow(ctx, "aion_deleteabnormalstatus",
			int(cidDel29AbnA), int(del29SkillIDA)).Scan(&aff4); err != nil {
			t.Fatalf("CallSPRow idempotent: %v", err)
		}
		if aff4 != 0 {
			t.Fatalf("re-delete: got %d, want 0", aff4)
		}
	})

	// --------- 00287 aion_deletechallengetask (3-table cascade) ---------
	t.Run("00287_DeleteChallengeTask", func(t *testing.T) {
		// Seed TaskA: main row + 2 quest leaves + 3 contributor rows = 6 total.
		mustExec(`INSERT INTO challenge_task
			(id, union_id, type, task_name_id, status, complete_count, last_complete_time)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			del29TaskA, int(101), int16(1), int(20001), int16(0), int(0), int(0))
		mustExec(`INSERT INTO challenge_task_quest
			(challenge_task_id, quest_id, status) VALUES ($1, $2, $3)`,
			del29TaskA, int(30001), int16(0))
		mustExec(`INSERT INTO challenge_task_quest
			(challenge_task_id, quest_id, status) VALUES ($1, $2, $3)`,
			del29TaskA, int(30002), int16(1))
		mustExec(`INSERT INTO challenge_task_contributor
			(challenge_task_id, char_id, contribute_point) VALUES ($1, $2, $3)`,
			del29TaskA, int(cidDel29AbnA), int(100))
		mustExec(`INSERT INTO challenge_task_contributor
			(challenge_task_id, char_id, contribute_point) VALUES ($1, $2, $3)`,
			del29TaskA, int(cidDel29SettingsA), int(50))
		mustExec(`INSERT INTO challenge_task_contributor
			(challenge_task_id, char_id, contribute_point) VALUES ($1, $2, $3)`,
			del29TaskA, int(cidDel29QuickbarA), int(25))

		// Seed TaskB: NO main row, only side-table residue (orphan-tolerance pin).
		mustExec(`INSERT INTO challenge_task_quest
			(challenge_task_id, quest_id, status) VALUES ($1, $2, $3)`,
			del29TaskB, int(30003), int16(0))
		mustExec(`INSERT INTO challenge_task_contributor
			(challenge_task_id, char_id, contribute_point) VALUES ($1, $2, $3)`,
			del29TaskB, int(cidDel29FavoriteA), int(10))

		// Happy path: TaskA → 1 (main) + 2 (quest) + 3 (contrib) = 6.
		var aff int
		if err := pool.CallSPRow(ctx, "aion_deletechallengetask",
			del29TaskA).Scan(&aff); err != nil {
			t.Fatalf("CallSPRow TaskA: %v", err)
		}
		if aff != 6 {
			t.Fatalf("TaskA cascade: got %d, want 6 (1+2+3)", aff)
		}
		assertCount("challenge_task/A",
			`SELECT COUNT(*) FROM challenge_task WHERE id=$1`, []any{del29TaskA}, 0)
		assertCount("challenge_task_quest/A",
			`SELECT COUNT(*) FROM challenge_task_quest WHERE challenge_task_id=$1`,
			[]any{del29TaskA}, 0)
		assertCount("challenge_task_contributor/A",
			`SELECT COUNT(*) FROM challenge_task_contributor WHERE challenge_task_id=$1`,
			[]any{del29TaskA}, 0)

		// Orphan case: TaskB has no main row but 1 quest + 1 contrib = 2.
		var aff2 int
		if err := pool.CallSPRow(ctx, "aion_deletechallengetask",
			del29TaskB).Scan(&aff2); err != nil {
			t.Fatalf("CallSPRow TaskB: %v", err)
		}
		if aff2 != 2 {
			t.Fatalf("TaskB orphan: got %d, want 2 (0+1+1)", aff2)
		}

		// Non-existent task → 0 silently.
		var aff3 int
		if err := pool.CallSPRow(ctx, "aion_deletechallengetask",
			del29TaskX).Scan(&aff3); err != nil {
			t.Fatalf("CallSPRow TaskX: %v", err)
		}
		if aff3 != 0 {
			t.Fatalf("TaskX missing: got %d, want 0", aff3)
		}

		// Idempotent re-cascade on TaskA → 0.
		var aff4 int
		if err := pool.CallSPRow(ctx, "aion_deletechallengetask",
			del29TaskA).Scan(&aff4); err != nil {
			t.Fatalf("CallSPRow TaskA re: %v", err)
		}
		if aff4 != 0 {
			t.Fatalf("TaskA re-cascade: got %d, want 0", aff4)
		}
	})

	// --------- 00288 aion_deleteclientsettings (wipe single blob row) ---------
	// Schema: (char_id PK, data_size SMALLINT, data BYTEA) — one row per char.
	t.Run("00288_DeleteClientSettings", func(t *testing.T) {
		mustExec(`INSERT INTO user_client_settings(char_id, data_size, data)
			VALUES ($1, $2, $3)`, cidDel29SettingsA, int16(3), []byte{0xAA, 0xBB, 0xCC})
		mustExec(`INSERT INTO user_client_settings(char_id, data_size, data)
			VALUES ($1, $2, $3)`, cidDel29ControlX, int16(1), []byte{0xFF})

		var aff int
		if err := pool.CallSPRow(ctx, "aion_deleteclientsettings",
			int(cidDel29SettingsA)).Scan(&aff); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if aff != 1 {
			t.Fatalf("settings A wipe: got %d, want 1", aff)
		}
		assertCount("settings/A",
			`SELECT COUNT(*) FROM user_client_settings WHERE char_id=$1`,
			[]any{cidDel29SettingsA}, 0)
		assertCount("settings/X intact",
			`SELECT COUNT(*) FROM user_client_settings WHERE char_id=$1`,
			[]any{cidDel29ControlX}, 1)

		var aff2 int
		if err := pool.CallSPRow(ctx, "aion_deleteclientsettings",
			int(cidDel29SettingsA)).Scan(&aff2); err != nil {
			t.Fatalf("CallSPRow A re: %v", err)
		}
		if aff2 != 0 {
			t.Fatalf("settings A re-wipe: got %d, want 0", aff2)
		}
	})

	// --------- 00289 aion_deleteclientquickbar (wipe single blob row) ---------
	t.Run("00289_DeleteClientQuickBar", func(t *testing.T) {
		mustExec(`INSERT INTO user_client_quickbar(char_id, data_size, data)
			VALUES ($1, $2, $3)`, cidDel29QuickbarA, int16(2), []byte{0x11, 0x22})
		mustExec(`INSERT INTO user_client_quickbar(char_id, data_size, data)
			VALUES ($1, $2, $3)`, cidDel29ControlX, int16(1), []byte{0x33})

		var aff int
		if err := pool.CallSPRow(ctx, "aion_deleteclientquickbar",
			int(cidDel29QuickbarA)).Scan(&aff); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if aff != 1 {
			t.Fatalf("quickbar A wipe: got %d, want 1", aff)
		}
		assertCount("quickbar/A",
			`SELECT COUNT(*) FROM user_client_quickbar WHERE char_id=$1`,
			[]any{cidDel29QuickbarA}, 0)
		assertCount("quickbar/X intact",
			`SELECT COUNT(*) FROM user_client_quickbar WHERE char_id=$1`,
			[]any{cidDel29ControlX}, 1)

		var aff2 int
		if err := pool.CallSPRow(ctx, "aion_deleteclientquickbar",
			int(cidDel29QuickbarA)).Scan(&aff2); err != nil {
			t.Fatalf("CallSPRow A re: %v", err)
		}
		if aff2 != 0 {
			t.Fatalf("quickbar A re-wipe: got %d, want 0", aff2)
		}
	})

	// --------- 00290 aion_deleteclientfavorite (wipe single blob row) ---------
	t.Run("00290_DeleteClientFavorite", func(t *testing.T) {
		mustExec(`INSERT INTO user_client_favorite(char_id, data_size, data)
			VALUES ($1, $2, $3)`, cidDel29FavoriteA, int16(4), []byte{0xDE, 0xAD, 0xBE, 0xEF})
		mustExec(`INSERT INTO user_client_favorite(char_id, data_size, data)
			VALUES ($1, $2, $3)`, cidDel29ControlX, int16(1), []byte{0x99})

		var aff int
		if err := pool.CallSPRow(ctx, "aion_deleteclientfavorite",
			int(cidDel29FavoriteA)).Scan(&aff); err != nil {
			t.Fatalf("CallSPRow A: %v", err)
		}
		if aff != 1 {
			t.Fatalf("favorite A wipe: got %d, want 1", aff)
		}
		assertCount("favorite/A",
			`SELECT COUNT(*) FROM user_client_favorite WHERE char_id=$1`,
			[]any{cidDel29FavoriteA}, 0)
		assertCount("favorite/X intact",
			`SELECT COUNT(*) FROM user_client_favorite WHERE char_id=$1`,
			[]any{cidDel29ControlX}, 1)

		var aff2 int
		if err := pool.CallSPRow(ctx, "aion_deleteclientfavorite",
			int(cidDel29FavoriteA)).Scan(&aff2); err != nil {
			t.Fatalf("CallSPRow A re: %v", err)
		}
		if aff2 != 0 {
			t.Fatalf("favorite A re-wipe: got %d, want 0", aff2)
		}
	})
}
