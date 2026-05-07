-- AionCore 5.8 — Sprint 1.1a batch 25 port: aion_PutHouseField
-- (housing decoration row INSERT — first row write for a house instance).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutHouseField.sql
-- Original (T-SQL):
--   INSERT house_field (id, addr_id, building_nameid, owner_id, owner_type,
--      owner_race, state, permission, comment_state, roof, outwall, frame,
--      door, garden, fence, inwall1..inwall6, infloor1..infloor6,
--      addon1..addon3, flag1..flag7, comment, owner_name,
--      update_time, created_time)
--   VALUES (..., GETDATE(), GETDATE())
--
-- Domain (`house_field`, batch 25 — first-introduction in this batch):
--   `house_field` is the static decoration manifest of every house in
--   the world (instanced and non-instanced). One row per house instance.
--   Stores the player's choice of roof / outwall / inwall / floor /
--   addon parts plus 7 boolean flags (visit settings / private flag etc.)
--   plus operator metadata (owner_id, name, legion, comment).
--
--   Sister SPs in this batch:
--     * 00261 aion_PutHouseField     (this file — INSERT, first row)
--     * 00262 aion_SetHouseField     (UPDATE, decoration change)
--     * 00263 aion_RemoveHouseField  (DELETE, house demolish/reset)
--   Sister SPs deferred to later batches:
--     * aion_GetHouseFieldAll        (full SELECT)
--     * aion_GetHouseFieldChargeAll  (charge-billing subset)
--     * aion_GetHouseFieldScriptAll  (script slot blob SELECT)
--     * aion_SetHouseFieldCharge     (charge counter UPDATE)
--     * aion_SetHouseFieldScript     (script slot blob UPSERT)
--
-- Schema:
--   `house_field` is FIRST INTRODUCED here. Column casing follows NCSoft
--   verbatim (lowercase snake_case for body — no quoting needed). Sized
--   conservatively from the NCSoft DDL:
--     id              INTEGER PRIMARY KEY    -- house instance id
--     addr_id         INTEGER NOT NULL       -- world addr (key for queries)
--     building_nameid INTEGER NOT NULL       -- name template id
--     owner_id        INTEGER NOT NULL       -- char_id (or 0 if NPC house)
--     owner_type      SMALLINT NOT NULL      -- TINYINT in NCSoft (0=char, ...)
--     owner_race      SMALLINT NOT NULL      -- TINYINT (0=Elyos, 1=Asmo, ...)
--     state           SMALLINT NOT NULL      -- TINYINT, lifecycle state
--     permission      SMALLINT NOT NULL      -- TINYINT, visit permission
--     comment_state   SMALLINT NOT NULL      -- TINYINT, comment visibility
--     roof, outwall, frame, door, garden, fence,
--     inwall1..inwall6, infloor1..infloor6, addon1..addon3
--                     INTEGER NOT NULL DEFAULT 0
--     flag1..flag7    BOOLEAN NOT NULL       -- BIT in NCSoft
--     comment         TEXT NOT NULL DEFAULT ''  -- nvarchar(64)
--     owner_name      TEXT NOT NULL DEFAULT ''  -- nvarchar(32)
--     legion_id       INTEGER NOT NULL DEFAULT 0
--     emblem_version  SMALLINT NOT NULL DEFAULT 0
--     emblem_bgcolor  INTEGER NOT NULL DEFAULT 0
--     update_time     TIMESTAMPTZ NOT NULL DEFAULT NOW()
--     created_time    TIMESTAMPTZ NOT NULL DEFAULT NOW()
--   NCSoft `BIT` is mapped to PG `BOOLEAN` (canonical). The NCSoft
--   comment column allows NULL (the GetHouseFieldAll SP uses ISNULL);
--   we keep the column NOT NULL with a '' default — equivalent for the
--   read path because PutHouseField always supplies a non-NULL value.
--
-- Translation notes:
--   * NCSoft INSERT skips legion_id / emblem_version / emblem_bgcolor
--     in the column list AND notes "useless param" in the comment for
--     these three. We pin EXACTLY: bind them in the parameter list (so
--     the call signature matches NCSoft) but write only the columns
--     that NCSoft writes — leaving legion_id / emblem_* at their column
--     DEFAULTs. This is bug-for-bug. The Set path (00262) DOES write
--     them, so the row picks them up on the first decoration change.
--   * Returns INTEGER (1 on success, 0 on conflict — strict widening
--     of NCSoft VOID; same convention as 00261's neighbours). PG
--     ON CONFLICT DO NOTHING handles the (theoretical) duplicate `id`
--     case gracefully — NCSoft would raise a PK violation.
--     Bug-for-bug pin: NCSoft does raise an error on duplicate id, but
--     the caller is responsible for never calling Put twice on the
--     same id. We choose ON CONFLICT DO NOTHING to avoid abort cascades
--     if the caller mis-sequences (a strict NCSoft mirror would mean
--     the entire PG transaction aborts; in our 1-call-per-stmt SP
--     contract that would still raise, just less gracefully). The 1
--     vs 0 return distinguishes the two cases for the caller.
--   * GETDATE() → NOW() (PG built-in). Both update_time and created_time
--     get the same NOW() snapshot — NCSoft semantics.
--
-- Bug-for-bug:
--   * No FK on owner_id, addr_id, building_nameid. Orphan rows are
--     possible (NCSoft same).
--   * legion_id / emblem_version / emblem_bgcolor are accepted as
--     parameters but DROPPED on the INSERT path (NCSoft same). Per
--     the NCSoft author's note "useless param" — Set picks them up.
--   * No validation that flag bits are 0/1; PG BOOLEAN handles
--     coercion from the bound bool. NCSoft BIT same.
--
-- Used by:
--   scripts/handlers/cm_house_field_buy.lua    -- house purchase / move-in
--   scripts/lib/house.lua

-- +goose Up
-- +goose StatementBegin
-- ====================================================================
-- house_field — FIRST INTRODUCTION.
-- One row per house instance in the world. Decoration manifest plus
-- operator metadata (owner / legion / emblem / comment / state).
-- Indexed on addr_id (most reads filter by world address) and on
-- owner_id (legion housing / GM lookups).
-- ====================================================================
CREATE TABLE IF NOT EXISTS house_field (
    id              INTEGER     PRIMARY KEY,
    addr_id         INTEGER     NOT NULL,
    building_nameid INTEGER     NOT NULL,
    owner_id        INTEGER     NOT NULL,
    owner_type      SMALLINT    NOT NULL,
    owner_race      SMALLINT    NOT NULL,
    state           SMALLINT    NOT NULL,
    permission      SMALLINT    NOT NULL,
    comment_state   SMALLINT    NOT NULL,
    roof            INTEGER     NOT NULL DEFAULT 0,
    outwall         INTEGER     NOT NULL DEFAULT 0,
    frame           INTEGER     NOT NULL DEFAULT 0,
    door            INTEGER     NOT NULL DEFAULT 0,
    garden          INTEGER     NOT NULL DEFAULT 0,
    fence           INTEGER     NOT NULL DEFAULT 0,
    inwall1         INTEGER     NOT NULL DEFAULT 0,
    inwall2         INTEGER     NOT NULL DEFAULT 0,
    inwall3         INTEGER     NOT NULL DEFAULT 0,
    inwall4         INTEGER     NOT NULL DEFAULT 0,
    inwall5         INTEGER     NOT NULL DEFAULT 0,
    inwall6         INTEGER     NOT NULL DEFAULT 0,
    infloor1        INTEGER     NOT NULL DEFAULT 0,
    infloor2        INTEGER     NOT NULL DEFAULT 0,
    infloor3        INTEGER     NOT NULL DEFAULT 0,
    infloor4        INTEGER     NOT NULL DEFAULT 0,
    infloor5        INTEGER     NOT NULL DEFAULT 0,
    infloor6        INTEGER     NOT NULL DEFAULT 0,
    addon1          INTEGER     NOT NULL DEFAULT 0,
    addon2          INTEGER     NOT NULL DEFAULT 0,
    addon3          INTEGER     NOT NULL DEFAULT 0,
    flag1           BOOLEAN     NOT NULL DEFAULT FALSE,
    flag2           BOOLEAN     NOT NULL DEFAULT FALSE,
    flag3           BOOLEAN     NOT NULL DEFAULT FALSE,
    flag4           BOOLEAN     NOT NULL DEFAULT FALSE,
    flag5           BOOLEAN     NOT NULL DEFAULT FALSE,
    flag6           BOOLEAN     NOT NULL DEFAULT FALSE,
    flag7           BOOLEAN     NOT NULL DEFAULT FALSE,
    comment         TEXT        NOT NULL DEFAULT '',
    owner_name      TEXT        NOT NULL DEFAULT '',
    legion_id       INTEGER     NOT NULL DEFAULT 0,
    emblem_version  SMALLINT    NOT NULL DEFAULT 0,
    emblem_bgcolor  INTEGER     NOT NULL DEFAULT 0,
    chargecount     INTEGER     NOT NULL DEFAULT 0,
    warningcount    INTEGER     NOT NULL DEFAULT 0,
    lastcharge      INTEGER     NOT NULL DEFAULT 0,
    update_time     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_time    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_house_field_addr  ON house_field(addr_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_house_field_owner ON house_field(owner_id);
-- +goose StatementEnd

-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthousefield(
    INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT, SMALLINT, SMALLINT,
    SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN,
    BOOLEAN, BOOLEAN, TEXT, TEXT, INTEGER, SMALLINT, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
-- Parameter order matches NCSoft verbatim:
--   id, addr_id, building_nameid, owner_id, owner_type, owner_race,
--   state, permission, comment_state,
--   roof, outwall, frame, door, garden, fence,
--   inwall1..6, infloor1..6, addon1..3,
--   flag1..7, comment, owner_name,
--   legion_id, emblem_version, emblem_bgcolor
-- The last three are accepted but DROPPED on insert (NCSoft pin).
CREATE OR REPLACE FUNCTION aion_puthousefield(
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
    affected INTEGER;
BEGIN
    -- NCSoft INSERT does NOT bind legion_id / emblem_version / emblem_bgcolor
    -- (the author commented "useless param" inline). We mirror exactly:
    -- bind them in the function signature (preserve caller contract) but
    -- omit them from the column list — they fall to the DEFAULT 0 / 0 / 0.
    INSERT INTO house_field (
        id, addr_id, building_nameid, owner_id, owner_type, owner_race,
        state, permission, comment_state,
        roof, outwall, frame, door, garden, fence,
        inwall1, inwall2, inwall3, inwall4, inwall5, inwall6,
        infloor1, infloor2, infloor3, infloor4, infloor5, infloor6,
        addon1, addon2, addon3,
        flag1, flag2, flag3, flag4, flag5, flag6, flag7,
        comment, owner_name,
        update_time, created_time
    )
    VALUES (
        _id, _addr_id, _building_nameid, _owner_id, _owner_type, _owner_race,
        _state, _permission, _comment_state,
        _roof, _outwall, _frame, _door, _garden, _fence,
        _inwall1, _inwall2, _inwall3, _inwall4, _inwall5, _inwall6,
        _infloor1, _infloor2, _infloor3, _infloor4, _infloor5, _infloor6,
        _addon1, _addon2, _addon3,
        _flag1, _flag2, _flag3, _flag4, _flag5, _flag6, _flag7,
        _comment, _owner_name,
        NOW(), NOW()
    )
    ON CONFLICT (id) DO NOTHING;

    GET DIAGNOSTICS affected = ROW_COUNT;
    -- Keep _legion_id / _emblem_* visible to the planner without warnings.
    PERFORM _legion_id, _emblem_version, _emblem_bgcolor;
    RETURN affected;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_puthousefield(
    INTEGER, INTEGER, INTEGER, INTEGER, SMALLINT, SMALLINT, SMALLINT,
    SMALLINT, SMALLINT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER,
    INTEGER, INTEGER, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN,
    BOOLEAN, BOOLEAN, TEXT, TEXT, INTEGER, SMALLINT, INTEGER
);
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_house_field_owner;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_house_field_addr;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS house_field;
-- +goose StatementEnd
