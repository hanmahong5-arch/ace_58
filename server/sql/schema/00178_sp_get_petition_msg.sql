-- AionCore 5.8 — Sprint 1.1a batch 8 port: aion_GetPetitionMsg (live + queued petition msg hydration).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetPetitionMsg.sql
-- Original (T-SQL):
--   SELECT @nLocalSv AS petition_sv_id, petition_msg FROM user_data WHERE char_id = @nCharId
--   UNION ALL
--   SELECT petition_sv_id, msg FROM user_petition_msg WHERE char_id = @nCharId
--
-- Translation notes:
--   * Two-source UNION ALL reflecting how 5.8 surfaces petition state:
--       1. The currently-active "live" petition_msg, persisted on user_data
--          (column added in 00032 pve_scaffold_round3). Tagged with the
--          local server id (@nLocalSv) so the client can render the origin
--          shard in multi-shard config — the SP echoes the parameter rather
--          than persisting it, the row's native sv_id is the caller's.
--       2. Queued cross-shard petition messages from user_petition_msg —
--          a per-char inbox of petition_sv_id + msg pairs that the petition
--          system enqueues when the player was offline at delivery time.
--   * UNION ALL (not UNION) preserves duplicates — a queued msg with the
--     same text as the live one is still surfaced separately (the client
--     deduplicates by sv_id in its own UI layer).
--   * No ORDER BY in T-SQL. Live row appears first by virtue of UNION ALL
--     left-side priority; we keep that natural order.
--   * `petition_msg` on user_data is nullable TEXT — coalesce to '' so the
--     wire payload is never NULL (5.8 client expects an empty string for
--     "no live petition", not a NULL).
--   * `user_petition_msg` is created here as the first (and only) consumer
--     in the SP catalogue. NCSoft schema: char_id INT, petition_sv_id INT,
--     msg TEXT, plus an implicit ordering column we don't expose.
--   * Function declared STABLE — pure read.
--
-- Used by:
--   scripts/handlers/cm_petition_msg_get.lua  -- on enter-world / petition UI open

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_petition_msg (
    id              BIGSERIAL PRIMARY KEY,
    char_id         INTEGER NOT NULL,
    petition_sv_id  INTEGER NOT NULL,
    msg             TEXT    NOT NULL DEFAULT ''
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_petition_msg_char ON user_petition_msg(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetitionmsg(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getpetitionmsg(_char_id INTEGER, _local_sv INTEGER)
RETURNS TABLE (
    petition_sv_id INTEGER,
    petition_msg   TEXT
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
        SELECT _local_sv AS petition_sv_id,
               COALESCE(ud.petition_msg, '') AS petition_msg
          FROM user_data ud
         WHERE ud.char_id = _char_id
        UNION ALL
        SELECT upm.petition_sv_id,
               upm.msg AS petition_msg
          FROM user_petition_msg upm
         WHERE upm.char_id = _char_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getpetitionmsg(INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_petition_msg_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_petition_msg;
-- +goose StatementEnd
