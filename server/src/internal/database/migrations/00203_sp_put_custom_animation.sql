-- AionCore 5.8 — Sprint 1.1a batch 13 port: aion_PutCustomAnimation (custom-anim grant + auto-equip).
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_PutCustomAnimation.sql
-- Original (T-SQL) — three statements in body, all run unconditionally:
--   (1) Update user_customAnimation
--          set useState = 0
--        where char_id=@charId AND animation_type=@animationType AND useState != 0
--   (2) Update user_customAnimation
--          set animation_type=@animationType, expire_time=@expireTime, useState=1
--        where char_id=@charId AND animation_id=@animationId
--   (3) if @@ROWCOUNT = 0
--          Insert user_customAnimation(char_id, animation_id, animation_type,
--                                      expire_time, useState)
--          values (@charId, @animationId, @animationType, @expireTime, 1)
--
-- Translation notes:
--   * Three-step contract: "this animation_id is now equipped; nothing else
--     of this animation_type can be equipped". The first UPDATE clears any
--     prior equip of the same TYPE; the second UPDATE re-equips THIS row
--     (or fails to find it); the conditional INSERT covers the first-time
--     grant. NCSoft's `@@ROWCOUNT` reads from the IMMEDIATELY PREVIOUS
--     statement (the second UPDATE), so the INSERT only fires when the
--     row didn't exist yet. Faithfully reproduced via PG ROW_COUNT diag.
--   * Schema column case: NCSoft uses `useState` (camelCase). Round 5
--     scaffold (00163) folded it to `use_state` (snake-case) per PG idioms.
--     We continue using `use_state` in the SP body — the on-the-wire byte
--     is the same single SMALLINT.
--   * `expire_time` is the unix-epoch second the equip lapses. 0 = expired.
--     Combined with the use_state=1 value, an entry can be soft-expired by
--     setting expire_time=0 while keeping use_state untouched (see 00163
--     filter `expire_time > 0`). PutCustomAnimation always sets use_state=1
--     and expire_time=@expireTime — so on a re-grant of an expired anim,
--     the player gets a freshly-rolling clock. NCSoft semantics preserved.
--   * Bug-for-bug: the first UPDATE ALSO clears use_state on the row we are
--     about to re-equip (because `useState != 0` matches it too). The second
--     UPDATE then re-sets it to 1, so the net effect is correct. PG path
--     does the same — no short-circuit optimisation (we'd need a 4-way
--     case analysis to know it's safe).
--   * Returns rows-affected of the FINAL operation (the INSERT path returns
--     1; the UPDATE path returns 1 if the second UPDATE found the row, else
--     0 because we then took the INSERT branch which makes it 1 — hence
--     the SP always returns 1 for normal flow). NCSoft itself returns no
--     value; we return 1 for caller observability.
--
-- Used by:
--   scripts/handlers/cm_custom_anim_use.lua   -- on /emote bind
--   scripts/lib/custom_animation.lua

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcustomanimation(INTEGER, INTEGER, SMALLINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putcustomanimation(
    _char_id          INTEGER,
    _animation_id     INTEGER,
    _animation_type   SMALLINT,
    _expire_time      BIGINT
) RETURNS INTEGER
LANGUAGE plpgsql AS $$
DECLARE
    update_cnt   INTEGER;
    affected_cnt INTEGER;
BEGIN
    -- Step 1: clear any currently-equipped row of the same animation_type
    -- (excluding rows already at use_state=0). Matches NCSoft's first UPDATE.
    UPDATE user_custom_animation
       SET use_state = 0
     WHERE char_id        = _char_id
       AND animation_type = _animation_type
       AND use_state     != 0;

    -- Step 2: try to update the target (animation_id, char_id) row. This
    -- re-asserts animation_type (callers might switch a row's type), refreshes
    -- expire_time, and pins use_state=1.
    UPDATE user_custom_animation
       SET animation_type = _animation_type,
           expire_time    = _expire_time,
           use_state      = 1
     WHERE char_id      = _char_id
       AND animation_id = _animation_id;
    GET DIAGNOSTICS update_cnt = ROW_COUNT;

    -- Step 3: if row didn't exist, INSERT a fresh one. Mirrors `if @@ROWCOUNT=0`.
    IF update_cnt = 0 THEN
        INSERT INTO user_custom_animation (
            char_id, animation_id, animation_type, expire_time, use_state
        ) VALUES (
            _char_id, _animation_id, _animation_type, _expire_time, 1
        );
        GET DIAGNOSTICS affected_cnt = ROW_COUNT;
    ELSE
        affected_cnt := update_cnt;
    END IF;

    RETURN affected_cnt;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putcustomanimation(INTEGER, INTEGER, SMALLINT, BIGINT);
-- +goose StatementEnd
