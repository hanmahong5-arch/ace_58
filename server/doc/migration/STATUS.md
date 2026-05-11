# SP Migration Status — AionCore 5.8

> **Last Updated**: 2026-05-11 (post-batch-29)
> **Source of Truth**: this file tracks every PG SP batch landed on `origin/main`.
> **Update protocol**: append a new row whenever a new `feat(database): SP batch N` commit ships.

---

## Headline

| Metric | Value |
|--------|-------|
| **Ported SPs (file-number)** | **277 / 1059** (26.2%) |
| **Distinct new PG functions** | **270 / 1059** (25.5%) — batch 29 is all-fresh (no restates) |
| **Q1 milestone (50 SPs)** | **超 554%** (achieved at batch 10, commit `de97774`) |
| **Batches landed** | 29 batches + 1 auction closure + 1 P1 sweep + 1 test debt sweep |
| **Domains covered** | 54 unique business domains (batch 29 deepens existing client-data + abnormal-status domains) |
| **Latest commit** | _pending_ — batch 29 (00286–00290) Delete 单条+客户端 cleanup |

Total target follows `aion_world_live` SP count (~1063); 1059 is the trimmed deduplicated working set.

---

## Batch History (chronological)

| Batch | SP # range  | Domain                                               | Commit    | SQL files | Test files | Insertions |
|-------|-------------|------------------------------------------------------|-----------|-----------|------------|------------|
| 1     | 00139–00143 | wallet (qina) + rate + bm_pack + block_check         | `33cd138` | 5         | 5          | +1640      |
| 2     | 00144–00148 | buddy + item_amount + familiar (read)                | `0fd07ba` | 5         | 5          | +1498      |
| 3     | 00149–00153 | buddy/block comment + offline buddy                  | `01e7708` | 5         | 5          | +1923      |
| 4     | 00154–00158 | client settings + comment (board)                    | `34fa4d1` | 5         | 5          | +1489      |
| 5     | 00159–00163 | emotion + quickbar + favorite + title + animation    | `15b7989` | 5         | 5          | +1418      |
| 6     | 00164–00168 | bookmark + recipe + item/combine/skill cool_time     | `2aceaad` | 5         | 5          | +1381      |
| 7     | 00169–00173 | macro + gather cool_time                             | `3a2d34d` | 5         | 5          | +1451      |
| 8     | 00174–00178 | petition (web_notify, msg) + house_object            | `23478e0` | 5         | 5          | +1434      |
| 9     | 00179–00183 | petition + promotion_cooltime + faction_quest        | `a94cbdf` | 5         | 5          | +1811      |
| 10    | 00184–00188 | promotion + overseas_event + faction_quest           | `de97774` | 5         | 0 (\*)     | +594       |
| 11    | 00189–00193 | wallet + world_bot                                   | `8e4abd9` | 5         | 3          | +1322      |
| 12    | 00194–00198 | guild (emblem / notices / history / join)            | `7ae1f27` | 5         | 5          | +1686      |
| 13    | 00199–00203 | emotion / bookmark / quickbar / animation (write)    | `9e77d9a` | 5         | 5          | +1785      |
| 14    | 00204–00208 | bingo + challenge_task + char_rank + stigma          | `b5d833d` | 5         | 5          | +1917      |
| 15    | 00209–00213 | abnormal_status + item_seal                          | `3bff249` | 5         | 5          | +2036      |
| 16    | 00214–00218 | enslave_stone + wardrobe + reform                    | `f2fca39` | 5         | 5          | +1704      |
| 17    | 00219–00223 | recipe-write + town + title-write                    | `6d1cbf4` | 5         | 5          | +1808      |
| 18    | 00224–00228 | auction_filter + auction_grace                       | `332b315` | 5         | 5          | +1474      |
| 19    | 00229–00233 | captcha + error_ignore                               | `3851cd5` | 5         | 2          | +1194      |
| 20    | 00234–00238 | familiar (pet/companion)                             | `060b30a` | 5         | 0          | +896       |
| 21    | 00239–00243 | bag/warehouse growth_tier_pay_stat                   | `cdeb2e5` | 5         | 5          | +1373      |
| 22    | 00244–00248 | item_cooltime + combine_cooltime + skill_skin + block_purge + punishment | `10c5fd1` | 5 | 5 | +1859 |
| 23    | 00249–00253 | pvp_env + char_exps_reward                           | `0051232` | 5         | 2          | +1331      |
| 24    | 00254–00258 | char_title + virtual_auth + access_allow_account     | `bd9e9a6` | 5         | 2          | +1256      |
| 25    | 00259–00263 | auction_betting + house_field                        | `eaf5142` | 5         | 2          | +2017      |
| 26    | 00264–00268 | infinity_season_record + spawn_area_rank             | `9c83eb2` | 5         | 2          | +1374      |
| AC\*\* | 00269–00275 | auction closure (lib hookup, 7 SPs)                  | `fdcb1aa` | 7         | 1          | +2234      |
| —     | (P1 sweep)  | re-fix 00210/00250/00192 (idempotency + bug-pin)     | `e0f86c1` | 3 edits   | 0          | small      |
| 27    | 00276–00280 | char 生命周期清理 (1 fresh + 4 idempotent restate)    | `cdddefb` | 5         | 1          | +1100      |
| 28    | 00281–00285 | Delete-杂项 (2 fresh + 3 idempotent restate)          | `58f49ac` | 5         | 1          | +1300      |
| —     | (test debt) | 14 FAIL + 1 STUCK → 0 FAIL (4 SP migration body fix)  | `5521f41` | 4 SP edit | 15 fixes   | +175/-59   |
| 29    | 00286–00290 | abnormal_status (single-row) + client_settings/quickbar/favorite + challenge_task — **5 fresh, 0 restate** | _pending_ | 5         | 1          | +700       |

\* batch 10 PG integration tests followed up in `9fea318` (test only commit).
\*\* AC = auction closure (7 SPs, not 5) — matched `scripts/lib/auction.lua` shape: insert_listing/insert_bid/get_by_id/get_search/cancel/settle/count_active. Listed as `AC` (not `27`) so batch numbering stays sequential.

**Idempotent-restate caveat** (batches 27/28): batch 27 SPs 00276/00277/00279/00280 and batch 28 SPs 00281/00282/00283 are `CREATE OR REPLACE FUNCTION` re-statements of bodies already present from earlier batch ports (00117/00120/00184/00122/00187/00225/00201). Order-independent; safe; counted in headline by file-number metric (272 / 1059) but only 3 distinct new PG functions added in this 10-file pair (00278 fresh + 00284/00285 fresh). Conservative "distinct PG functions" headline = 265 / 1059 (25.0%).

Test-coverage soft spots: batch 19 (2/5), batch 20 (0/5), batch 23 (2/5), batch 24-26 (2/5 each), batch 27/28 (1/5 each) ship SQL with partial Go integration tests. Tracked as backfill items, not blocking new batches.

Pre-batch baseline (round 9–10 era, commits `5f37fb2` → `0ac9b4f`): an additional **~125 SPs** ported during character-lifecycle / instance-dungeon / mail / warehouse / bind-point work — together with the 115 batched SPs above this gives the 240 / 1059 headline. (The 125 figure is derived from `240 − 115`; precise commit-level audit deferred to next sweep.)

---

## 54 Domains Touched

instance/dungeon, friend/offline, settings, comment, macro, buddy, bm_pack,
quest_acquired, legion_announce, petition, house_object, promotion_cooltime,
overseas_event, faction_quest, wallet, world_bot, guild, emotion, bookmark,
quickbar, custom_animation, bingo, challenge_task, char_rank, stigma,
abnormal_status, item_seal, enslave_stone, wardrobe, reform, recipe-write,
town, title-write, auction_filter, auction_grace, captcha, error_ignore,
familiar, growth_tier_pay_stat, item_cooltime, combine_cooltime, skill_skin,
block_purge, punishment, pvp_env, char_exps_reward,
**char_title (write_attr / update / read)**, **virtual_auth_account**,
**access_allow_account**, **auction_betting (read / delete)**,
**house_field (put / set / remove)**, **infinity_season_record**,
**spawn_area_rank (list / set / delete)**, **auction_closure (lib hookup)**.

---

## File Layout (per SP)

Each batch lands three coordinated files per SP, plus one Go integration test:

```
server/sql/schema/<NNN>_sp_<name>.sql                              # canonical PG DDL
server/src/internal/database/migrations/<NNN>_sp_<name>.sql        # embedded migration mirror
server/src/internal/database/sp_<name>_test.go                     # pgx integration test
```

Batches 15–23 currently ship SQL only; integration test backfill is tracked separately and not blocking.

---

## How to Append a New Batch

1. Run the batch (see `aion-58-server-dev` skill / per-batch playbook).
2. Commit with the convention `feat(database): SP batch N 移植 (5 SP, NNNNN-NNNNN) — <domain>`.
3. Append a row to the table above.
4. Update the headline `Ported SPs` count and bump `Last Updated`.
5. If a brand-new domain appears, append it to the **46 Domains** list (keep alphabetical-ish grouping by feature family).

---

## Cross-References

- Architecture & golden rules: [`../dev-guide.md`](../dev-guide.md)
- NCSoft T-SQL ground truth: `../../../ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/`
- Embedded migration loader: `../../src/internal/database/migrations/`
- Schema canonical copy: `../../sql/schema/`
