-- AionCore 5.8 — Sprint 1.1a batch 25 port: aion_SetHouseField
-- (housing decoration row UPDATE — applies a decoration change).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_SetHouseField.sql
-- Original (T-SQL):
--   select @owner_name = USER_ID from user_data where char_id = @owner_id
--   UPDATE house_field SET addr_id=@addr_id, building_nameid=@building_nameid,
--      owner_id=@owner_id, owner_type=@owner_type, owner_race=@owner_race,
--      state=@state, permission=@permission, comment_state=@comment_state,
--      roof=@roof, outwall=@outwall, ..., infloor6=@infloor6,
--      addon1..3, flag1..7,
--      comment=@comment, owner_name=@owner_name, update_time=GETDATE(),
--      legion_id=@legion_id, emblem_version=@emblem_version,
--      emblem_bgcolor=@emblem_bgcolor
--   WHERE id=@id;
--
-- Domain (`house_field`, batch 25 — sister to 00261, 00263):
--   Decoration change UPDATE. Differs from 00261 PutHouseField in three
--   important ways:
--     1. UPDATE (not INSERT) — house_field.id row must already exist.
--     2. Writes legion_id / emblem_version / emblem_bgcolor (00261 drops
--        those three — see 00261 header for the "useless param" pin).
--     3. **Overrides @owner_name from user_data.name** — NCSoft does
--        `select @owner_name = USER_ID from user_data where char_id = @owner_id`
--        BEFORE the UPDATE. The caller's @owner_name is silently
--        discarded if user_data has a row for owner_id.
--
-- Schema:
--   `house_field` is created by 00261. The 00261 file also adds the
--   `chargecount`, `warningcount`, `lastcharge` columns (used by
--   aion_SetHouseFieldCharge in a later batch). This SP does NOT touch
--   those three — pin: only Set updates the decoration manifest.
--
-- Translation notes:
--   * Pre-UPDATE owner_name override: NCSoft reads user_data.USER_ID
--     into @owner_name. Our user_data table uses column `name` (see
--     00002_pve_scaffold.sql — the AionCore canonical char-name field).
--     We mirror the override semantics: if user_data has a row for
--     _owner_id with non-empty name, that name overrides the supplied
--     parameter. If no row exists (NPC house, deleted character), the
--     supplied parameter wins. Pinned bug-for-bug: NCSoft also leaves
--     @owner_name unchanged when user_data lookup fails (T-SQL
--     `select @x = ...` is a no-op on empty result).
--   * GETDATE() → NOW(). NCSoft updates ONLY update_time on Set; the
--     created_time stays from the Put call. Pinned.
--   * Returns INTEGER (0 or 1, rows-affected). 0 means "id not found";
--     caller may want to fall back to Put. NCSoft returns nothing
--     (VOID) — strict widening.
--
-- Bug-for-bug:
--   * @owner_name override is silent — clients can never set a custom
--     display name on the house ledger; it tracks user_data canonical
--     name. NCSoft pinned (privacy / consistency feature).
--   * Negative / out-of-range tinyint params accepted at SMALLINT level.
--   * No transaction wrapping the SELECT-then-UPDATE pair. In NCSoft
--     this is acceptable because user_data.USER_ID for a given char_id
--     is effectively immutable (changes only via GM tooling). Pinned.
--   * If id does not exist → returns 0, no error. Caller handles.
--
-- Used by:
--   scripts/handlers/cm_house_field_decorate.lua  -- decoration change
--   scripts/handlers/cm_house_legion_assign.lua   -- legion housing
--   scripts/lib/house.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethousefield(
    INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT, SMALLINT, SMALLINT,
    SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN,
    BOOLEAN, BOOLEAN, TEXT, TEXT, INTEGER, SMALLINT, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
-- Parameter order matches NCSoft verbatim — same as 00261 PutHouseField.
-- The trailing legion_id / emblem_version / emblem_bgcolor are USED by
-- this SP (in contrast to 00261 which drops them).
CREATE OR REPLACE FUNCTION aion_sethousefield(
    _id              INTEGER,
    _addr_id         INTEGER,
    _building_nameid INTEGER,
    _owner_id        INTEGER,
    _owner_type      SMALLINT,
    _owner_race      SMALLINT,
    _state           SMALLINT,
    _permission      SMALLINT,
    _comment_state   SMALLINT,
    _roof            INTEGER,
    _outwall         INTEGER,
    _frame           INTEGER,
    _door            INTEGER,
    _garden          INTEGER,
    _fence           INTEGER,
    _inwall1         INTEGER,
    _inwall2         INTEGER,
    _inwall3         INTEGER,
    _inwall4         INTEGER,
    _inwall5         INTEGER,
    _inwall6         INTEGER,
    _infloor1        INTEGER,
    _infloor2        INTEGER,
    _infloor3        INTEGER,
    _infloor4        INTEGER,
    _infloor5        INTEGER,
    _infloor6        INTEGER,
    _addon1          INTEGER,
    _addon2          INTEGER,
    _addon3          INTEGER,
    _flag1           BOOLEAN,
    _flag2           BOOLEAN,
    _flag3           BOOLEAN,
    _flag4           BOOLEAN,
    _flag5           BOOLEAN,
    _flag6           BOOLEAN,
    _flag7           BOOLEAN,
    _comment         TEXT,
    _owner_name      TEXT,
    _legion_id       INTEGER,
    _emblem_version  SMALLINT,
    _emblem_bgcolor  INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    affected     INTEGER;
    canonical    TEXT;
    final_name   TEXT;
BEGIN
    -- T-SQL pre-step: `select @owner_name = USER_ID from user_data where char_id = @owner_id`
    -- T-SQL `SELECT @x = col` is a no-op when no row matches — the variable
    -- keeps the value the caller supplied. We mirror that exactly.
    --   * row found → use canonical user_data.name
    --   * no row    → use supplied parameter
    -- We additionally treat NULL/empty canonical as "no row" to match
    -- NCSoft semantics where USER_ID was a non-NULL VARCHAR column.
    SELECT u.name INTO canonical
      FROM user_data u
     WHERE u.char_id = _owner_id;

    IF canonical IS NULL OR canonical = '' THEN
        final_name := _owner_name;
    ELSE
        final_name := canonical;
    END IF;

    UPDATE house_field
       SET addr_id         = _addr_id,
           building_nameid = _building_nameid,
           owner_id        = _owner_id,
           owner_type      = _owner_type,
           owner_race      = _owner_race,
           state           = _state,
           permission      = _permission,
           comment_state   = _comment_state,
           roof            = _roof,
           outwall         = _outwall,
           frame           = _frame,
           door            = _door,
           garden          = _garden,
           fence           = _fence,
           inwall1         = _inwall1,
           inwall2         = _inwall2,
           inwall3         = _inwall3,
           inwall4         = _inwall4,
           inwall5         = _inwall5,
           inwall6         = _inwall6,
           infloor1        = _infloor1,
           infloor2        = _infloor2,
           infloor3        = _infloor3,
           infloor4        = _infloor4,
           infloor5        = _infloor5,
           infloor6        = _infloor6,
           addon1          = _addon1,
           addon2          = _addon2,
           addon3          = _addon3,
           flag1           = _flag1,
           flag2           = _flag2,
           flag3           = _flag3,
           flag4           = _flag4,
           flag5           = _flag5,
           flag6           = _flag6,
           flag7           = _flag7,
           comment         = _comment,
           owner_name      = final_name,
           legion_id       = _legion_id,
           emblem_version  = _emblem_version,
           emblem_bgcolor  = _emblem_bgcolor,
           update_time     = NOW()
     WHERE id = _id;

    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_sethousefield(
    INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT, SMALLINT, SMALLINT,
    SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN,
    BOOLEAN, BOOLEAN, TEXT, TEXT, INTEGER, SMALLINT, INTEGER
);
-- +goose StatementEnd
