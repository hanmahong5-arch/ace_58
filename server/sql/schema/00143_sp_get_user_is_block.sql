-- AionCore 5.8 — Sprint 1.1a batch 1 port: aion_GetUserIsBlock (block-state lookup).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetUserIsBlock.sql
-- Original (T-SQL):
--   PROCEDURE aion_GetUserIsBlock(@charId int, @targetname nvarchar(50),
--                                  @targetId int OUT, @isblock int OUT,
--                                  @optionflag int OUT)
--   AS
--   BEGIN
--     SET @targetId = 0
--     SELECT @targetId = ISNULL(char_id,0)
--       FROM user_data
--      WHERE user_id = @targetname AND delete_complete_date = 0
--        AND race = (SELECT race FROM user_data WHERE char_id = @charId)
--     SET @isblock = 0
--     SET @optionflag = 0
--     IF @targetId IS NOT NULL AND @targetId != 0
--     BEGIN
--       IF EXISTS (SELECT block_id FROM user_block
--                   WHERE char_id = @targetId AND block_id = @charId)
--         SET @isblock = 1
--       SELECT @optionflag = ISNULL(optionflags,0)
--         FROM user_data WHERE char_id = @targetid
--     END
--   END
--
-- Flow: viewer's race is read first, then the target name is looked up *only*
-- among same-race chars (cross-faction whisper/friend is forbidden in AION),
-- skipping soft-deleted chars. If the target exists, we then check whether
-- the *target* has the *viewer* in their block list (note: NCSoft schema is
-- "char_id blocks block_id" → here we ask whether viewer (charId) appears
-- as a block_id under target (targetId)). Finally read target's optionflags
-- (privacy flags, do-not-disturb, etc.).
--
-- The schema diverges from NCSoft on one column name: NCSoft has both
-- `delete_date` and `delete_complete_date`. Our user_data only carries
-- `delete_date` (set when the soft-delete grace begins), and rows older
-- than 7 days are hard-deleted by aion_DeleteCharOnExpiredCheck. Filtering
-- by `delete_date = 0` therefore gives the same end-effect as NCSoft's
-- `delete_complete_date = 0` (both mean "this char is currently usable").
--
-- T-SQL returned data via 3 OUTPUT parameters; PG plpgsql returns a single
-- composite row (target_id, is_block, optionflag). This always returns ONE
-- row — even when the target lookup fails — so the caller can do an
-- unconditional Scan and react to target_id=0 as "no such recipient" without
-- needing to handle "0 rows" separately. The caller-side mail / friend Lua
-- glue already follows this convention for AddBlock / GetBlock.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserisblock(INTEGER, TEXT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getuserisblock(
    _char_id     INTEGER,
    _target_name TEXT
)
RETURNS TABLE (
    out_target_id  INTEGER,
    out_is_block   INTEGER,
    out_optionflag INTEGER
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    viewer_race  SMALLINT;
    target_id    INTEGER := 0;
    is_block     INTEGER := 0;
    option_flag  INTEGER := 0;
BEGIN
    -- (1) Read the viewer's race; if the viewer doesn't exist or is
    --     soft-deleted we still proceed (target lookup will fail naturally
    --     because viewer_race is NULL → race = NULL never matches).
    SELECT ud.race INTO viewer_race
      FROM user_data ud
     WHERE ud.char_id     = _char_id
       AND ud.delete_date = 0
     LIMIT 1;

    -- (2) Resolve target name within the viewer's race.
    SELECT COALESCE(ud.char_id, 0) INTO target_id
      FROM user_data ud
     WHERE ud.user_id     = _target_name
       AND ud.delete_date = 0
       AND ud.race        = viewer_race
     LIMIT 1;

    IF target_id IS NOT NULL AND target_id <> 0 THEN
        -- (3) Did the target block the viewer?
        IF EXISTS (
            SELECT 1
              FROM user_block ub
             WHERE ub.char_id  = target_id
               AND ub.block_id = _char_id
        ) THEN
            is_block := 1;
        END IF;

        -- (4) Read target's optionflags (privacy / do-not-disturb bits).
        SELECT COALESCE(ud.optionflags, 0) INTO option_flag
          FROM user_data ud
         WHERE ud.char_id = target_id;
    END IF;

    -- Always emit exactly one row so callers can Scan() unconditionally.
    out_target_id  := COALESCE(target_id, 0);
    out_is_block   := is_block;
    out_optionflag := option_flag;
    RETURN NEXT;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getuserisblock(INTEGER, TEXT);
-- +goose StatementEnd
