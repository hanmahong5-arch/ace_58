//go:build integration
// +build integration

// Package database — Round 12 A3 cross-round PG integration canaries.
//
// Purpose
// -------
// 已知缺口 #2 (known-gaps.md): 119 SP 之前全用 mockDB 测；任何 SP 签名漂移
// (参数顺序、返回类型、入参类型) 在单测里看不出来，只有真打到 PG 才暴露。
// 本文件提供 6 个跨 Round 的 canary：每个 Round 选 1 个有代表性的 SP，
// 走 "最小 fixture → SP call → 断言 OUT 参 + 副作用 → cleanup" 的固定链路。
//
// Goal
// ----
// 不验业务正确性 (那是 sp_pve_round{6..10}_test.go 的职责)。
// 只验三件事:
//   1. SP 函数存在 (Postgres CALL/SELECT 不抛 undefined function);
//   2. 签名匹配 (参数个数、类型与 Go 调用点一致, 不抛 invalid input);
//   3. 入库副作用可观测 (确保不是只编译过、运行时哑火).
//
// Gating
// ------
// 本文件用 `//go:build integration` tag 隔离, 默认 `go test ./...` 不会跑.
// CI 与本地都用以下命令显式触发:
//
//	PGTEST_DSN=postgres://postgres:postgres@127.0.0.1:5432/aion_world_live?sslmode=disable \
//	  go test -tags=integration ./internal/database/... -count=1 -v
//
// PGTEST_DSN 缺失时 t.Skip(), 不让 CI 因为没 PG 就 fail.
//
// Canary SP 清单 (6 个, 每个 Round 一个代表):
//
//	#1 housing       (R8) aion_PutHouseInstant + aion_GetHouseInstant
//	#2 pet           (R8) aion_PutPetNew2 + aion_GetPetListNew2
//	#3 instance      (R9) aion_SetUserInstance + aion_GetUserInstance
//	#4 condition     (R9) aion_SetInstanceCondition (insert + update branch)
//	#5 monster       (R9) aion_SetMonsterAchievement + aion_GetMonsterAchievementList
//	#6 char-lifecycle(R10) aion_SetCharDeleteTime + aion_ClearCharDeleteTime
//
// Cleanup band: char_id 9_080_000..9_080_099 (Round 12 reserve, 不与 R6/R8/R10
// 已用 band 重叠).

package database

import (
	"context"
	"os"
	"testing"
	"time"
)

// canaryDSN 读 PGTEST_DSN; 缺失返回空串, 调用方 Skip.
// 注意: 与 testDSN() 用的 AION_TEST_PG_* 系列分离 — 那是分 Round 套件的
// 历史约定, 本文件刻意走独立环境变量名, 让 CI workflow 配置最简 (只一个 var).
func canaryDSN() string {
	return os.Getenv("PGTEST_DSN")
}

// canaryCleanup 清理 Round-12 canary 占用的所有 band 行.
// 与 round{6..10}Cleanup 同款 LIFO 双注册策略.
func canaryCleanup(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	// 表名/列名 已对照 sql/schema/* 实际定义:
	//   instance.PK              = instance_id (NOT id)
	//   world_extcondition.world_num = canary instance_id (R9 实际写入表)
	stmts := []string{
		`DELETE FROM user_pet                  WHERE char_id BETWEEN 9080000 AND 9080099`,
		`DELETE FROM user_instance             WHERE char_id BETWEEN 9080000 AND 9080099`,
		`DELETE FROM user_monster_achievement  WHERE char_id BETWEEN 9080000 AND 9080099`,
		`DELETE FROM houseobject               WHERE owner_id BETWEEN 9080000 AND 9080099`,
		`DELETE FROM house_instant             WHERE id BETWEEN 9080000 AND 9080099`,
		`DELETE FROM world_extcondition        WHERE world_num BETWEEN 9580000 AND 9580099`,
		`DELETE FROM instance                  WHERE instance_id BETWEEN 9580000 AND 9580099`,
		`DELETE FROM user_data                 WHERE char_id BETWEEN 9080000 AND 9080099`,
	}
	for _, stmt := range stmts {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("canaryCleanup %q: %v", stmt, err)
		}
	}
}

// setupCanary 启动 PG 池 + 跑 migration + 注册前后清理.
// migration 走 embed.FS (与生产同源), 顺便验证 mirror_schema 跑过.
func setupCanary(t *testing.T) (*Pool, context.Context) {
	t.Helper()
	dsn := canaryDSN()
	if dsn == "" {
		t.Skip("integration skipped: PGTEST_DSN not set " +
			"(set e.g. postgres://postgres:postgres@127.0.0.1:5432/aion_world_live?sslmode=disable)")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	t.Cleanup(cancel)

	if err := Migrate(ctx, dsn); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	pool, err := NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("NewPool: %v", err)
	}
	t.Cleanup(pool.Close)

	canaryCleanup(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		canaryCleanup(t, bg, pool)
	})
	return pool, ctx
}

// seedCanaryChar 给 canary 用的最小 user_data 行 (与 seedRound8Char 相同模式,
// 但 user_id 前缀刻意改成 'r12_' 以便人工排查谁在污染).
func seedCanaryChar(t *testing.T, ctx context.Context, p *Pool, charID int, name string) {
	t.Helper()
	_, err := p.Inner().Exec(ctx,
		`INSERT INTO user_data(char_id, name, user_id) VALUES ($1, $2, $3)
		 ON CONFLICT (char_id) DO NOTHING`,
		charID, name, "r12_"+name)
	if err != nil {
		t.Fatalf("seedCanaryChar: %v", err)
	}
}

// =========================================================================
// 6 个 canary 测试 (每个独立, 失败一个不影响其他)
// =========================================================================

// canary #1 — Round 8 housing.
// 验 PutHouseInstant 写入后 GetHouseInstant 能读回 owner 的 user_id.
func TestCanary_R8_Housing(t *testing.T) {
	pool, ctx := setupCanary(t)
	const cid = 9080001
	seedCanaryChar(t, ctx, pool, cid, "HouseOwner")

	if err := pool.CallSPExec(ctx, "aion_puthouseinstant",
		cid, int16(2), int16(1), 0, 0); err != nil {
		t.Fatalf("aion_puthouseinstant: %v", err)
	}

	var (
		st, perm     int16
		inwall, infl int
		uid          string
	)
	if err := pool.CallSPRow(ctx, "aion_gethouseinstant", cid).
		Scan(&st, &perm, &inwall, &infl, &uid); err != nil {
		t.Fatalf("aion_gethouseinstant: %v", err)
	}
	if st != 2 || uid != "r12_HouseOwner" {
		t.Fatalf("housing roundtrip: st=%d uid=%q", st, uid)
	}
}

// canary #2 — Round 8 pet.
// 验 PutPetNew2 返回 BIGSERIAL id; GetPetListNew2 能查到 1 条.
func TestCanary_R8_Pet(t *testing.T) {
	pool, ctx := setupCanary(t)
	const cid = 9080010
	seedCanaryChar(t, ctx, pool, cid, "PetOwner")

	var id int64
	if err := pool.CallSPRow(ctx, "aion_putpetnew2",
		"Canary", []byte{0xCA, 0xFE},
		cid, 555900, int16(1),
		int64(0), int64(0), int64(0), int64(0),
		int64(0), int64(0), int64(0), int64(0),
		1, int(time.Now().Unix())).Scan(&id); err != nil {
		t.Fatalf("aion_putpetnew2: %v", err)
	}
	if id <= 0 {
		t.Fatalf("aion_putpetnew2: returned non-positive id=%d", id)
	}

	rows, err := pool.CallSP(ctx, "aion_getpetlistnew2", cid)
	if err != nil {
		t.Fatalf("aion_getpetlistnew2: %v", err)
	}
	defer rows.Close()
	var n int
	for rows.Next() {
		n++
	}
	if n != 1 {
		t.Fatalf("aion_getpetlistnew2: got %d rows, want 1", n)
	}
}

// canary #3 — Round 9 user_instance.
// 验 SetUserInstance(6-arg variant) → GetUserInstance 能读回.
func TestCanary_R9_Instance(t *testing.T) {
	pool, ctx := setupCanary(t)
	const cid = 9080020
	seedCanaryChar(t, ctx, pool, cid, "InstUser")

	now := int(time.Now().Unix())
	// 6-arg variant: (char_id, mask_id, world_id, server_id, reentrance_time, count)
	if err := pool.CallSPExec(ctx, "aion_setuserinstance",
		cid, 9580001, 210050000, 1, now+3600, 1); err != nil {
		t.Fatalf("aion_setuserinstance: %v", err)
	}

	rows, err := pool.CallSP(ctx, "aion_getuserinstance", cid)
	if err != nil {
		t.Fatalf("aion_getuserinstance: %v", err)
	}
	defer rows.Close()
	var n int
	for rows.Next() {
		n++
	}
	if n < 1 {
		t.Fatalf("aion_getuserinstance: got %d rows, want >=1", n)
	}
}

// canary #4 — Round 9 instance_condition.
// 验 SetInstanceCondition 的 INSERT + UPDATE 双分支 (同 hash 第二次必须更新而非插入).
func TestCanary_R9_InstanceCondition(t *testing.T) {
	pool, ctx := setupCanary(t)
	futureTime := int(time.Now().Unix()) + 3600

	// 先 seed 一个 instance 行 (FK 约束).
	if err := pool.CallSPExec(ctx, "aion_setinstance",
		9580031, futureTime, 0, ""); err != nil {
		t.Fatalf("aion_setinstance seed: %v", err)
	}

	// First call → INSERT.
	if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
		9580031, "boss_killed", 12345, 1); err != nil {
		t.Fatalf("aion_setinstancecondition insert: %v", err)
	}
	// Same (instance_id, var_name, hash) → UPDATE branch (no duplicate row).
	if err := pool.CallSPExec(ctx, "aion_setinstancecondition",
		9580031, "boss_killed", 12345, 5); err != nil {
		t.Fatalf("aion_setinstancecondition update: %v", err)
	}

	// SP 实际写入 world_extcondition (world_type=1, world_num=instance_id);
	// 见 00100_sp_set_instance_condition.sql.
	var n int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT COUNT(*) FROM world_extcondition
		  WHERE world_type=1 AND world_num=9580031
		    AND variable='boss_killed' AND variable_hash=12345`).Scan(&n); err != nil {
		t.Fatalf("verify count: %v", err)
	}
	if n != 1 {
		t.Fatalf("upsert produced %d rows, want 1", n)
	}
}

// canary #5 — Round 9 monster bestiary.
// 验 SetMonsterAchievement 写入 + GetMonsterAchievementList 读回.
func TestCanary_R9_MonsterBestiary(t *testing.T) {
	pool, ctx := setupCanary(t)
	const cid = 9080040
	seedCanaryChar(t, ctx, pool, cid, "Hunter")

	if err := pool.CallSPExec(ctx, "aion_setmonsterachievement",
		cid, 777, 10, int16(1)); err != nil {
		t.Fatalf("aion_setmonsterachievement: %v", err)
	}

	rows, err := pool.CallSP(ctx, "aion_getmonsterachievementlist", cid)
	if err != nil {
		t.Fatalf("aion_getmonsterachievementlist: %v", err)
	}
	defer rows.Close()
	var n int
	for rows.Next() {
		n++
	}
	if n != 1 {
		t.Fatalf("monster list: got %d rows, want 1", n)
	}
}

// canaryCleanupR13 清掉 R13 mail/warehouse 用的 char + item + mail 行。
// 与 canaryCleanup 互补：char_id 9_130_xxx 段，避免与 R6/8/10 重叠。
func canaryCleanupR13(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	stmts := []string{
		`DELETE FROM user_mail WHERE to_id BETWEEN 9130000 AND 9130099 OR from_id BETWEEN 9130000 AND 9130099`,
		`DELETE FROM user_item_option WHERE id IN (SELECT id FROM user_item WHERE char_id BETWEEN 9130000 AND 9130099)`,
		`DELETE FROM user_item WHERE char_id BETWEEN 9130000 AND 9130099`,
		`DELETE FROM user_data WHERE char_id BETWEEN 9130000 AND 9130099`,
	}
	for _, stmt := range stmts {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("canaryCleanupR13 %q: %v", stmt, err)
		}
	}
}

// canary #7 — Round 13 mail (writer + list + read + delete).
// 验 aion_mailwrite_20160804 INSERT → aion_maillist 列表 → aion_mailread 标已读
// → aion_maildelete 删除（rc=0 表示成功）。
func TestCanary_R13_Mail(t *testing.T) {
	pool, ctx := setupCanary(t)
	canaryCleanupR13(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		canaryCleanupR13(t, bg, pool)
	})

	const sender, recipient = 9130001, 9130002
	seedCanaryChar(t, ctx, pool, sender, "Sender")
	seedCanaryChar(t, ctx, pool, recipient, "Recip")

	now := int(time.Now().Unix())

	// Step 1: write mail (no item attachment, no kinah, no AP) → return new mail_id.
	var mailID int64
	if err := pool.CallSPRow(ctx, "aion_mailwrite_20160804",
		recipient, "Recip", sender, "Sender",
		"hello", "body",
		int64(0),  // item_id
		0,         // item_nameid
		int64(0),  // item_amount
		int64(0),  // money
		int64(0),  // abyss_point
		2,         // warehouse (cube)
		now,       // arrive_time
		0,         // express_mail
	).Scan(&mailID); err != nil {
		t.Fatalf("aion_mailwrite_20160804: %v", err)
	}
	if mailID <= 0 {
		t.Fatalf("aion_mailwrite_20160804: returned non-positive id=%d", mailID)
	}

	// Step 2: list inbox — must contain the new mail.
	rows, err := pool.CallSP(ctx, "aion_maillist", recipient, now+10, 100)
	if err != nil {
		t.Fatalf("aion_maillist: %v", err)
	}
	listCount := 0
	for rows.Next() {
		listCount++
	}
	rows.Close()
	if listCount < 1 {
		t.Fatalf("aion_maillist: got %d rows, want >=1", listCount)
	}

	// Step 3: read it — sets state=1, returns body row.
	rows2, err := pool.CallSP(ctx, "aion_mailread", recipient, mailID)
	if err != nil {
		t.Fatalf("aion_mailread: %v", err)
	}
	readCount := 0
	for rows2.Next() {
		readCount++
	}
	rows2.Close()
	if readCount != 1 {
		t.Fatalf("aion_mailread: got %d rows, want 1", readCount)
	}

	// Step 4: delete — RETURNS TABLE(rc, prev_state); rc=0 means OK.
	var rc int
	var prevState int16
	if err := pool.CallSPRow(ctx, "aion_maildelete", recipient, mailID).
		Scan(&rc, &prevState); err != nil {
		t.Fatalf("aion_maildelete: %v", err)
	}
	if rc != 0 {
		t.Fatalf("aion_maildelete rc=%d, want 0", rc)
	}
}

// canary #8 — Round 13 mail attachment claim (aion_mailgetitem flag=1 = money branch).
// 写入带 1000 money 的邮件 → MailGetItem(flag=1) → 验 money cleared + rc=0。
func TestCanary_R13_MailGetItem(t *testing.T) {
	pool, ctx := setupCanary(t)
	canaryCleanupR13(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		canaryCleanupR13(t, bg, pool)
	})

	const sender, recipient = 9130011, 9130012
	seedCanaryChar(t, ctx, pool, sender, "MoneySender")
	seedCanaryChar(t, ctx, pool, recipient, "MoneyRecip")

	var mailID int64
	if err := pool.CallSPRow(ctx, "aion_mailwrite_20160804",
		recipient, "MoneyRecip", sender, "MoneySender",
		"$$$$", "with money",
		int64(0), 0, int64(0),
		int64(1000), // money
		int64(0),    // abyss_point
		2, int(time.Now().Unix()), 0,
	).Scan(&mailID); err != nil {
		t.Fatalf("aion_mailwrite_20160804: %v", err)
	}

	// Claim money (flag=1, warehouse=0/cube).
	var rc int
	var outItemID, outMoney, outAP int64
	if err := pool.CallSPRow(ctx, "aion_mailgetitem",
		recipient, mailID, 0, 1).
		Scan(&rc, &outItemID, &outMoney, &outAP); err != nil {
		t.Fatalf("aion_mailgetitem: %v", err)
	}
	if rc != 0 {
		t.Fatalf("aion_mailgetitem rc=%d, want 0 (success)", rc)
	}
	if outMoney != 1000 {
		t.Fatalf("aion_mailgetitem out_money=%d, want 1000", outMoney)
	}

	// Re-claim same flag — money already 0 → rc=2 (no_attached_asset).
	if err := pool.CallSPRow(ctx, "aion_mailgetitem",
		recipient, mailID, 0, 1).
		Scan(&rc, &outItemID, &outMoney, &outAP); err != nil {
		t.Fatalf("aion_mailgetitem second call: %v", err)
	}
	if rc != 2 {
		t.Fatalf("aion_mailgetitem second-claim rc=%d, want 2 (no_attached_asset)", rc)
	}
}

// canary #9 — Round 13 warehouse transfer (aion_setitemwarehouse_20111227).
// PutItem 一件物品在 cube → SetItemWarehouse(cube→account) → GetItemList(account)
// 看到此件 → SetItemWarehouse(account→cube) 反向。
func TestCanary_R13_Warehouse(t *testing.T) {
	pool, ctx := setupCanary(t)
	canaryCleanupR13(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		canaryCleanupR13(t, bg, pool)
	})

	const cid = 9130020
	seedCanaryChar(t, ctx, pool, cid, "WhUser")

	// 直接 INSERT 一件 user_item 行（warehouse=0=cube）。绕 PutItem 是因为 PutItem
	// 签名 41 参数过宽，本 canary 只验 SetItemWarehouse 行级 transfer。
	var itemID int64
	if err := pool.Inner().QueryRow(ctx,
		`INSERT INTO user_item (char_id, name_id, slot_id, amount, tid, slot, warehouse)
		 VALUES ($1, 100001, 0, 1, 100001, 0, 0) RETURNING id`,
		cid).Scan(&itemID); err != nil {
		t.Fatalf("seed user_item: %v", err)
	}
	// user_item_option 是 user_item 的 sister 表（CASCADE FK），SetItemWarehouse
	// 会同步更新它，必须先 INSERT 否则 UPDATE 静默 0-row。
	if _, err := pool.Inner().Exec(ctx,
		`INSERT INTO user_item_option (id, char_id) VALUES ($1, $2)`,
		itemID, cid); err != nil {
		t.Fatalf("seed user_item_option: %v", err)
	}

	// Transfer cube → account warehouse (warehouse=2, owner unchanged).
	if err := pool.CallSPExec(ctx, "aion_setitemwarehouse_20111227",
		itemID, int16(2), cid); err != nil {
		t.Fatalf("aion_setitemwarehouse_20111227 deposit: %v", err)
	}

	// GetItemList(char_id, warehouse=2) 必须看到这件。
	rows, err := pool.CallSP(ctx, "aion_getitemlist_20120102", cid, 2)
	if err != nil {
		t.Fatalf("aion_getitemlist_20120102 deposit-check: %v", err)
	}
	depCount := 0
	for rows.Next() {
		depCount++
	}
	rows.Close()
	if depCount != 1 {
		t.Fatalf("after deposit: got %d rows in account warehouse, want 1", depCount)
	}

	// Transfer back account → cube。
	if err := pool.CallSPExec(ctx, "aion_setitemwarehouse_20111227",
		itemID, int16(0), cid); err != nil {
		t.Fatalf("aion_setitemwarehouse_20111227 withdraw: %v", err)
	}
	rows2, err := pool.CallSP(ctx, "aion_getitemlist_20120102", cid, 0)
	if err != nil {
		t.Fatalf("aion_getitemlist_20120102 withdraw-check: %v", err)
	}
	wCount := 0
	for rows2.Next() {
		wCount++
	}
	rows2.Close()
	if wCount != 1 {
		t.Fatalf("after withdraw: got %d rows in cube, want 1", wCount)
	}
}

// canary #6 — Round 10 char-lifecycle.
// 验 SetCharDeleteTime 标记软删 → ClearCharDeleteTime 还原 (delete_date=0).
func TestCanary_R10_CharLifecycle(t *testing.T) {
	pool, ctx := setupCanary(t)
	const cid = 9080050
	seedCanaryChar(t, ctx, pool, cid, "DelChar")

	// Mark for delete.
	if err := pool.CallSPExec(ctx, "aion_setchardeletetime",
		cid, 1700000000); err != nil {
		t.Fatalf("aion_setchardeletetime: %v", err)
	}
	var dd1 int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT delete_date FROM user_data WHERE char_id=$1`, cid).Scan(&dd1); err != nil {
		t.Fatalf("verify mark: %v", err)
	}
	if dd1 != 1700000000 {
		t.Fatalf("delete_date not set: got %d", dd1)
	}

	// Restore (cancel delete).
	if err := pool.CallSPExec(ctx, "aion_clearchardeletetime", cid); err != nil {
		t.Fatalf("aion_clearchardeletetime: %v", err)
	}
	var dd2 int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT delete_date FROM user_data WHERE char_id=$1`, cid).Scan(&dd2); err != nil {
		t.Fatalf("verify clear: %v", err)
	}
	if dd2 != 0 {
		t.Fatalf("delete_date not cleared: got %d", dd2)
	}
}

// canaryCleanupBatch20 清理 batch-20 familiar 测试占用的 char_id band 9580001..9580099。
// 与 R12 / R13 的 cleanup 互不重叠（R12 用 9080000s, R13 用 9130000s）。
// 顺序: user_familiar / user_data_ext 先于 user_data — 即便没有显式 FK，
// 测试自身的契约要求 master/char 在父表存在。
func canaryCleanupBatch20(t *testing.T, ctx context.Context, p *Pool) {
	t.Helper()
	stmts := []string{
		`DELETE FROM user_familiar WHERE char_id BETWEEN 9580001 AND 9580099`,
		`DELETE FROM user_data_ext WHERE char_id BETWEEN 9580001 AND 9580099`,
		`DELETE FROM user_data     WHERE char_id BETWEEN 9580001 AND 9580099`,
	}
	for _, stmt := range stmts {
		if _, err := p.Inner().Exec(ctx, stmt); err != nil {
			t.Fatalf("canaryCleanupBatch20 %q: %v", stmt, err)
		}
	}
}

// canary #B20-1 — batch 20 familiar write-path: PutFamiliar → SetFamiliarInfo
// → SetFamiliarGrowthPoint → SetFamiliarName。
// 验签名 + 副作用串行可达（不验业务正确性 — 那是 Lua 测试的职责）。
func TestCanary_B20_FamiliarWritePath(t *testing.T) {
	pool, ctx := setupCanary(t)
	canaryCleanupBatch20(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		canaryCleanupBatch20(t, bg, pool)
	})

	const cid = 9580001
	seedCanaryChar(t, ctx, pool, cid, "FamMaster")

	now := int64(time.Now().UnixMilli())

	// Step 1: PutFamiliar — returns BIGSERIAL id.
	var dbID int64
	if err := pool.CallSPRow(ctx, "aion_putfamiliar",
		"Bobo",          // _name
		cid,             // _master_id
		111,             // _base_name_id
		111,             // _cur_name_id
		0,               // _evolve_cnt
		now,             // _create_time
		now,             // _update_time
		int16(0),        // _safety_flag
		0,               // _growth_point
		0, 0, 0, 0, 0, 0, // _slot1.._slot6
		int16(1), // _looting_state
	).Scan(&dbID); err != nil {
		t.Fatalf("aion_putfamiliar: %v", err)
	}
	if dbID <= 0 {
		t.Fatalf("aion_putfamiliar: returned non-positive id=%d", dbID)
	}

	// Step 2: SetFamiliarInfo_20180226 — bulk slots + growth + looting update.
	if err := pool.CallSPExec(ctx, "aion_setfamiliarinfo_20180226",
		dbID, cid,
		1001, 1002, 1003, 1004, 1005, 1006, // _slot1.._slot6
		int16(0), // _looting_state (toggle off)
		500,      // _growth_point
		now+1,    // _update_time
	); err != nil {
		t.Fatalf("aion_setfamiliarinfo_20180226: %v", err)
	}

	// Step 3: SetFamiliarGrowthPoint — focused growth bump.
	if err := pool.CallSPExec(ctx, "aion_setfamiliargrowthpoint",
		dbID, cid, 750, now+2); err != nil {
		t.Fatalf("aion_setfamiliargrowthpoint: %v", err)
	}

	// Step 4: SetFamiliarName — rename.
	if err := pool.CallSPExec(ctx, "aion_setfamiliarname",
		dbID, cid, "Bobo2", now+3); err != nil {
		t.Fatalf("aion_setfamiliarname: %v", err)
	}

	// Verify cumulative state — slots from step 2, growth from step 3, name
	// from step 4, update_time from the latest write.
	var (
		gotName                            string
		gotGrowth                          int
		gotS1, gotS2, gotS3, gotS4, gotS5, gotS6 int
		gotLooting                         int16
		gotUpdateTime                      int64
	)
	if err := pool.Inner().QueryRow(ctx,
		`SELECT name, growth_point, slot1, slot2, slot3, slot4, slot5, slot6,
                looting_state, update_time
           FROM user_familiar
          WHERE id=$1 AND char_id=$2`,
		dbID, cid).Scan(&gotName, &gotGrowth,
		&gotS1, &gotS2, &gotS3, &gotS4, &gotS5, &gotS6,
		&gotLooting, &gotUpdateTime); err != nil {
		t.Fatalf("verify familiar row: %v", err)
	}
	if gotName != "Bobo2" {
		t.Fatalf("name: got %q want %q", gotName, "Bobo2")
	}
	if gotGrowth != 750 {
		t.Fatalf("growth_point: got %d want 750", gotGrowth)
	}
	if gotS1 != 1001 || gotS6 != 1006 {
		t.Fatalf("slots: got s1=%d s6=%d want 1001/1006", gotS1, gotS6)
	}
	if gotLooting != 0 {
		t.Fatalf("looting_state: got %d want 0", gotLooting)
	}
	if gotUpdateTime != now+3 {
		t.Fatalf("update_time: got %d want %d (last write)", gotUpdateTime, now+3)
	}
}

// canary #B20-2 — batch 20 SetFamiliarEnergy: UPSERT into user_data_ext
// (first introduction of the side-table) + bug-for-bug last_summon_familiar
// pin verification.
func TestCanary_B20_FamiliarEnergyUpsert(t *testing.T) {
	pool, ctx := setupCanary(t)
	canaryCleanupBatch20(t, ctx, pool)
	t.Cleanup(func() {
		bg, c2 := context.WithTimeout(context.Background(), 30*time.Second)
		defer c2()
		canaryCleanupBatch20(t, bg, pool)
	})

	const cid = 9580002
	seedCanaryChar(t, ctx, pool, cid, "EnergyUser")

	// First call → INSERT branch (no prior row).
	if err := pool.CallSPExec(ctx, "aion_setfamiliarenergy",
		cid, 100, int16(1)); err != nil {
		t.Fatalf("aion_setfamiliarenergy insert: %v", err)
	}
	var energy, lastSummon int
	var autocharge int16
	if err := pool.Inner().QueryRow(ctx,
		`SELECT familiar_energy, familiar_energy_autocharge, last_summon_familiar
           FROM user_data_ext WHERE char_id=$1`, cid).
		Scan(&energy, &autocharge, &lastSummon); err != nil {
		t.Fatalf("verify insert: %v", err)
	}
	if energy != 100 || autocharge != 1 {
		t.Fatalf("after insert: energy=%d autocharge=%d want 100/1",
			energy, autocharge)
	}
	// Bug-for-bug pin: last_summon_familiar shadows familiar_energy.
	if lastSummon != 100 {
		t.Fatalf("after insert: last_summon_familiar=%d want 100 (NCSoft pin)",
			lastSummon)
	}

	// Second call → UPDATE branch (row already exists).
	if err := pool.CallSPExec(ctx, "aion_setfamiliarenergy",
		cid, 250, int16(0)); err != nil {
		t.Fatalf("aion_setfamiliarenergy update: %v", err)
	}
	if err := pool.Inner().QueryRow(ctx,
		`SELECT familiar_energy, familiar_energy_autocharge, last_summon_familiar
           FROM user_data_ext WHERE char_id=$1`, cid).
		Scan(&energy, &autocharge, &lastSummon); err != nil {
		t.Fatalf("verify update: %v", err)
	}
	if energy != 250 || autocharge != 0 || lastSummon != 250 {
		t.Fatalf("after update: e=%d ac=%d lsf=%d want 250/0/250",
			energy, autocharge, lastSummon)
	}

	// 3rd call must NOT produce a duplicate row (PK constraint + ON CONFLICT).
	var rowCount int
	if err := pool.Inner().QueryRow(ctx,
		`SELECT COUNT(*) FROM user_data_ext WHERE char_id=$1`, cid).
		Scan(&rowCount); err != nil {
		t.Fatalf("dup check: %v", err)
	}
	if rowCount != 1 {
		t.Fatalf("user_data_ext row count for char_id=%d: %d (want 1)",
			cid, rowCount)
	}
}
