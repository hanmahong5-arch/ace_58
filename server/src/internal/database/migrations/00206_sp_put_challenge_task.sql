-- AionCore 5.8 — Sprint 1.1a batch 14 port: aion_PutChallengeTask (challenge-task creation).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutChallengeTask.sql
-- Original (T-SQL):
--   IF EXISTS (Select id From challenge_task(nolock)
--               Where union_id=@nUnionId AND type=@nType
--                 AND task_name_id=@nTaskNameId)
--       return 1;  -- 중복 도전 과제 (duplicate challenge task)
--   ELSE
--       Insert Into challenge_task(union_id, type, task_name_id, status,
--                                  complete_count, last_complete_time)
--           Values(@nUnionId, @nType, @nTaskNameId, @nStatus, 0, 0);
--       IF @@ERROR <> 0
--           return 2; -- insert 실패 (insert failure)
--       set @nTaskDbId = @@IDENTITY
--   return 0;
--
-- Translation notes:
--   * Three distinct return codes pinned:
--       0 = success (also writes new id into _task_db_id)
--       1 = duplicate (no insert; _task_db_id remains NULL)
--       2 = insert failure (caught by EXCEPTION block in PG)
--   * NCSoft uses an OUTPUT parameter `@nTaskDbId`; PG returns a composite
--     `(rc INTEGER, task_db_id BIGINT)` instead — caller pattern-matches.
--   * `id BIGSERIAL` — challenge_task is a long-tail audit-ish table; the
--     T-SQL uses IDENTITY (default INT) but BIGINT is forward-safe and the
--     OUT param is `bigint` in T-SQL, so types align byte-for-byte.
--   * Composite UNIQUE on (union_id, type, task_name_id) is intentionally
--     NOT added at table level. We probe with SELECT first to mimic NCSoft's
--     race-tolerant flow (the duplicate check is a soft pre-check). Adding
--     a hard UNIQUE would corrupt the rc=1 path under concurrency.
--   * `last_complete_time = 0` and `complete_count = 0` are initial values;
--     SetChallengeTaskComplete (a future port) will tick them up.
--
-- Bug-for-bug:
--   * Race window between EXISTS probe and INSERT — two concurrent grants
--     of the same (union_id, type, task_name_id) can both insert. NCSoft
--     accepts this; the entropy roadmap can dedup at read time if needed.
--   * `nolock` (T-SQL) ≈ READ UNCOMMITTED. PG default is READ COMMITTED,
--     which is stricter. Net effect: PG misses fewer dirty reads = same or
--     better behaviour. No semantic regression.
--
-- Used by:
--   scripts/handlers/cm_challenge_task_grant.lua  (Q2 — challenge task UI)

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS challenge_task (
    id                 BIGSERIAL PRIMARY KEY,
    union_id           INTEGER   NOT NULL,
    type               SMALLINT  NOT NULL,
    task_name_id       INTEGER   NOT NULL,
    status             SMALLINT  NOT NULL,
    complete_count     INTEGER   NOT NULL DEFAULT 0,
    last_complete_time INTEGER   NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_challenge_task_union ON challenge_task(union_id, type, task_name_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchallengetask(INTEGER, SMALLINT, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putchallengetask(
    _union_id      INTEGER,
    _type          SMALLINT,
    _task_name_id  INTEGER,
    _status        SMALLINT,
    OUT rc         INTEGER,
    OUT task_db_id BIGINT
) AS $$
BEGIN
    -- Soft duplicate check — bug-for-bug from NCSoft's `IF EXISTS` probe.
    IF EXISTS (
        SELECT id FROM challenge_task
         WHERE union_id     = _union_id
           AND type         = _type
           AND task_name_id = _task_name_id
    ) THEN
        rc         := 1;
        task_db_id := NULL;
        RETURN;
    END IF;

    BEGIN
        INSERT INTO challenge_task (
            union_id, type, task_name_id, status, complete_count, last_complete_time
        ) VALUES (
            _union_id, _type, _task_name_id, _status, 0, 0
        )
        RETURNING id INTO task_db_id;
        rc := 0;
    EXCEPTION WHEN OTHERS THEN
        -- Mirrors `IF @@ERROR <> 0 return 2` — any insertion failure surfaces
        -- as rc=2 with task_db_id NULL.
        rc         := 2;
        task_db_id := NULL;
    END;
END;
$$ LANGUAGE plpgsql;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putchallengetask(INTEGER, SMALLINT, INTEGER, SMALLINT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_challenge_task_union;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS challenge_task;
-- +goose StatementEnd
