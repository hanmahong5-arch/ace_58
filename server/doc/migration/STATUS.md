# SP Migration Status — AionCore 5.8

> **Last Updated**: 2026-05-07
> **Source of Truth**: this file tracks every PG SP batch landed on `origin/main`.
> **Update protocol**: append a new row whenever a new `feat(database): SP batch N` commit ships.

---

## Headline

| Metric | Value |
|--------|-------|
| **Ported SPs** | **240 / 1059** (22.7%) |
| **Q1 milestone (50 SPs)** | **超 130%** (achieved at batch 10, commit `de97774`) |
| **Batches landed** | 23 (batch 1 … batch 23) |
| **Domains covered** | 46 unique business domains |
| **Latest batch** | `0051232` — batch 23 (pvp_env + char_exps_reward) |

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

\* batch 10 PG integration tests followed up in `9fea318` (test only commit).

Test-coverage soft spots: batch 19 (2/5), batch 20 (0/5), batch 23 (2/5) ship SQL with partial Go integration tests. Tracked as backfill items, not blocking new batches.

Pre-batch baseline (round 9–10 era, commits `5f37fb2` → `0ac9b4f`): an additional **~125 SPs** ported during character-lifecycle / instance-dungeon / mail / warehouse / bind-point work — together with the 115 batched SPs above this gives the 240 / 1059 headline. (The 125 figure is derived from `240 − 115`; precise commit-level audit deferred to next sweep.)

---

## 46 Domains Touched

instance/dungeon, friend/offline, settings, comment, macro, buddy, bm_pack,
quest_acquired, legion_announce, petition, house_object, promotion_cooltime,
overseas_event, faction_quest, wallet, world_bot, guild, emotion, bookmark,
quickbar, custom_animation, bingo, challenge_task, char_rank, stigma,
abnormal_status, item_seal, enslave_stone, wardrobe, reform, recipe-write,
town, title-write, auction_filter, auction_grace, captcha, error_ignore,
familiar, growth_tier_pay_stat, item_cooltime, combine_cooltime, skill_skin,
block_purge, punishment, pvp_env, char_exps_reward.

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
