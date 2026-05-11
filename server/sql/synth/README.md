# sql/synth — LLM 生成 SP 暂存区

## 本目录用途

存放由 `ACE_5.8/server/src/internal/spsynth` 包的 LLM Agentic Synthesis 流程生成的
PL/pgSQL 存储过程草稿，以及对应的原始 T-SQL 参考文件。

**流程**：T-SQL 输入 → spsynth.Synthesizer → LLM 转换 → 人工审核通过 → 归档至 `../`（主 sql 目录）。

本目录中的 `.sql` 文件均为草稿，**未经人工审核，不可直接在生产环境执行**。

---

## SP 选取标准（MVP 起点）

以下标准用于筛选 Round 17 MVP 阶段的示范 SP，降低首批转换复杂度：

| 标准 | 说明 |
|------|------|
| ≤50 行 | 便于 LLM 一次性处理，减少截断风险 |
| 纯 SELECT | 无副作用，影子测试安全，等价性验证成本低 |
| 无游标 | 游标语义在 PG 中需要额外适配，留待后期 |
| 无临时表（#tmp） | 临时表生命周期语义差异大，需专项规则 |
| 无 TRY/CATCH | 异常处理语法差异，需对应到 EXCEPTION WHEN OTHERS |
| 入参 ≤3 | 参数多时属性测试的搜索空间急剧扩大 |

首批选用：`aion_GetGuildId`（12 行，1 入参，纯 SELECT，无游标无临时表无异常处理）。

---

## 移植策略路线图

```
阶段 0（当前）：简单 SELECT SP
  标准：≤50 行 / 纯 SELECT / 无游标 / 无临时表 / 无 try-catch / 入参≤3
  示例：aion_GetGuildId、aion_GetUserQina、aion_GetAccountExtraInfo
  目标：跑通 spsynth 框架，建立 prompt/validator 基线

阶段 1：含 IF/ELSE 分支
  新增挑战：分支条件翻译（IF...ELSE → IF...THEN...ELSE...END IF）
  示例：aion_GetHouseFieldChargeAll、aion_GetUserWeeklyRewardTime
  验证：PropertyValidator 随机参数 × 200 轮

阶段 2：含临时表（#tmp）
  新增挑战：#tmp 生命周期 → CREATE TEMP TABLE ON COMMIT DROP
  示例：各种 TopN 排行榜 SP
  验证：ShadowValidator 影子流量回放

阶段 3：含游标（CURSOR / FETCH）
  新增挑战：T-SQL 游标 → PG FOR row IN ... LOOP / OPEN/FETCH/CLOSE
  示例：批量更新类 SP
  验证：行级 diff + 副作用状态对比

阶段 4：含事务与嵌套 SP 调用（EXEC / sp_executesql）
  新增挑战：XACT_ABORT / SAVE TRANSACTION → SAVEPOINT
  验证：需要事务沙箱 + 回滚测试夹具

阶段 5（全量）：1395 SP 批量流水线
  LLM 批处理 + 自动验证 + 人工抽检（≥5%）→ 归档至 sql/
```

---

## 与 sql/ 主目录的关系

```
ACE_5.8/server/sql/
├── synth/          ← 本目录：LLM 生成草稿（未审核）
│   ├── *.tsql      原始 T-SQL 参考（来自 ai/wiki/raw/47104-sp-dump/）
│   ├── *.sql       LLM 生成的 PL/pgSQL 草稿
│   └── README.md   本文件
├── schema/         已审核的 DDL（表结构）
└── *.sql           已审核、可执行的 PL/pgSQL SP（生产就绪）
```

**归档条件**（草稿 → 主目录）：
1. 人工 DBA 审核代码逻辑正确
2. 等价性验证 DiffCount = 0（PropertyValidator 200 轮 + ShadowValidator ≥100 组）
3. 在 dev 数据库执行无报错
4. 更新 decision-log 记录归档决定
