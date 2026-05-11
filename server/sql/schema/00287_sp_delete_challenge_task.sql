-- AionCore 5.8 — batch 29 / 2 of 5: aion_DeleteChallengeTask — 3-table cascade.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_DeleteChallengeTask.sql
-- Original (T-SQL):
--   -- 빌더 커맨드 전용 (builder-command only — admin/QA tooling)
--   CREATE PROCEDURE [dbo].[aion_DeleteChallengeTask]
--       @nTaskDbId as bigint
--   AS
--   BEGIN
--       SET NOCOUNT ON;
--       Delete From challenge_task            Where id                = @nTaskDbId;
--       Delete From challenge_task_quest      Where challenge_task_id = @nTaskDbId;
--       Delete From challenge_task_contributor Where challenge_task_id = @nTaskDbId;
--   END
--
-- Translation notes:
--   * challenge_task created at 00206; the two side tables
--     (challenge_task_quest, challenge_task_contributor) were not migrated
--     by any prior batch. CREATE TABLE IF NOT EXISTS here on first use —
--     forward-compatible with a future PutChallengeTaskQuest /
--     PutChallengeTaskContributor port. Column shapes match NCSoft's table
--     schemas (challenge_task_id FK column + payload columns inferred from
--     T-SQL caller code).
--   * Three independent DELETEs — NO transaction in NCSoft, so a partial
--     failure (e.g. constraint trip on one of the side tables) leaves
--     residue. We mirror that exactly: each DELETE runs in autocommit;
--     no SAVEPOINT, no exception trap. Bug-for-bug pinned.
--   * Returns INTEGER = sum of all three rows-affected counts. Strict
--     widening of NCSoft VOID, sibling of 00284 (vendor wipe — also
--     multi-table sum return).
--
-- Bug-for-bug:
--   * Unknown task_db_id → 0+0+0 = 0, no error. Pinned.
--   * No referential integrity checks — orphan rows in the side tables are
--     untouched if FK column drifts. Pinned (NCSoft sits on schemaless
--     trust).
--
-- Used by:
--   scripts/admin/gm_clear_challenge_task.lua  -- QA/builder-command
--   (Production code does NOT call this — it is intentionally a builder
--    teardown path, per the Korean header comment "빌더 커맨드 전용".)

-- +goose Up
-- +goose StatementBegin
-- Side table 1: challenge_task_quest — per-task quest leaf records.
-- Column shape is conservative (FK + quest_id + status); future
-- PutChallengeTaskQuest port may ALTER to add more leaves, but the
-- DELETE column we depend on (challenge_task_id) is stable.
CREATE TABLE IF NOT EXISTS challenge_task_quest (
    challenge_task_id BIGINT  NOT NULL,
    quest_id          INTEGER NOT NULL,
    status            SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (challenge_task_id, quest_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_challenge_task_quest_task
    ON challenge_task_quest(challenge_task_id);
-- +goose StatementEnd

-- +goose StatementBegin
-- Side table 2: challenge_task_contributor — chars who contributed.
CREATE TABLE IF NOT EXISTS challenge_task_contributor (
    challenge_task_id BIGINT  NOT NULL,
    char_id           INTEGER NOT NULL,
    contribute_point  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (challenge_task_id, char_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_challenge_task_contributor_task
    ON challenge_task_contributor(challenge_task_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletechallengetask(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
-- _task_db_id : NCSoft @nTaskDbId (BIGINT — see 00206 BIGSERIAL).
-- Returns rows-deleted SUM across challenge_task + _quest + _contributor.
CREATE OR REPLACE FUNCTION aion_deletechallengetask(
    _task_db_id BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    a INTEGER;
    b INTEGER;
    c INTEGER;
BEGIN
    DELETE FROM challenge_task             WHERE id                = _task_db_id;
    GET DIAGNOSTICS a = ROW_COUNT;

    DELETE FROM challenge_task_quest       WHERE challenge_task_id = _task_db_id;
    GET DIAGNOSTICS b = ROW_COUNT;

    DELETE FROM challenge_task_contributor WHERE challenge_task_id = _task_db_id;
    GET DIAGNOSTICS c = ROW_COUNT;

    RETURN a + b + c;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_deletechallengetask(BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_challenge_task_contributor_task;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS challenge_task_contributor;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_challenge_task_quest_task;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS challenge_task_quest;
-- +goose StatementEnd
