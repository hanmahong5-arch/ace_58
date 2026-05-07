-- AionCore 5.8 — Sprint 1.1a batch 9 port: aion_SetPetitionMsg (live + queued petition msg writer).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetPetitionMsg.sql
-- Original (T-SQL):
--   IF @nPetSvId = @nLocalSv
--       UPDATE user_data SET petition_msg = @sPetMsg WHERE char_id = @nCharId
--   ELSE
--   BEGIN
--       IF EXISTS (SELECT id FROM user_petition_msg(updlock)
--                   WHERE char_id = @nCharId AND petition_sv_id = @nPetSvId)
--           UPDATE user_petition_msg SET msg = @sPetMsg
--            WHERE char_id = @nCharId AND petition_sv_id = @nPetSvId
--       ELSE
--           INSERT INTO user_petition_msg VALUES (@nCharId, @nPetSvId, @sPetMsg)
--   END
--
-- Translation notes:
--   * Cross-shard branch on (petition_sv_id == local_sv_id):
--       - Same-shard  → UPDATE the live `petition_msg` column on user_data
--         (added in 00032 pve_scaffold_round3, paired-read by 00178).
--       - Cross-shard → UPSERT into the queued user_petition_msg inbox
--         (table created in 00178). NCSoft's UPDLOCK-then-IF-EXISTS pattern
--         has a race window between the SELECT and INSERT on a (char_id,
--         petition_sv_id) collision; PG `INSERT ... ON CONFLICT DO UPDATE`
--         is genuinely atomic at the index level (last-writer-wins).
--   * For ON CONFLICT to fire we need a UNIQUE constraint on the upsert key.
--     00178 created only a non-unique idx_user_petition_msg_char (covering
--     index for the GetPetitionMsg lookup). We add the UNIQUE composite key
--     here as IF NOT EXISTS so this migration is idempotent and 00178's GET
--     still benefits from the (char_id) index for the all-shards scan.
--   * Returns total rows-affected (1 for either branch — both UPDATE-1 and
--     UPSERT-1 settle to one row touched). Matches the 00170/00175 convention
--     so the caller can sanity-check the round-trip.
--   * Same-shard branch: if the user_data row does not exist (mid-deletion
--     race with the petition system), UPDATE silently no-ops and we return 0.
--     5.8 client treats 0 as "msg dropped, retry on next tick" — matches
--     T-SQL semantics where the UPDATE just affected zero rows.
--
-- Used by:
--   scripts/handlers/cm_petition_msg_set.lua   -- player edits petition msg
--   scripts/lib/petition.lua

-- +goose Up
-- +goose StatementBegin
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_petition_msg_char_sv
    ON user_petition_msg(char_id, petition_sv_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetitionmsg(INTEGER, INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setpetitionmsg(
    _char_id   INTEGER,
    _pet_sv_id INTEGER,
    _local_sv  INTEGER,
    _msg       TEXT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected_cnt INTEGER;
BEGIN
    IF _pet_sv_id = _local_sv THEN
        -- Same-shard: live msg lives on user_data.petition_msg.
        UPDATE user_data
           SET petition_msg = _msg
         WHERE char_id = _char_id;
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    ELSE
        -- Cross-shard: queue / overwrite in user_petition_msg by (char, sv).
        INSERT INTO user_petition_msg(char_id, petition_sv_id, msg)
        VALUES (_char_id, _pet_sv_id, _msg)
        ON CONFLICT (char_id, petition_sv_id) DO UPDATE
           SET msg = EXCLUDED.msg;
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    END IF;
    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setpetitionmsg(INTEGER, INTEGER, INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_petition_msg_char_sv;
-- +goose StatementEnd
