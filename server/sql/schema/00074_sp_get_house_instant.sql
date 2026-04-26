-- AionCore 5.8 — Sprint 1.1a Round 8 (Track B6) port: aion_GetHouseInstant.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_GetHouseInstant.sql
--
-- Joins house_instant with user_data on house_instant.id = user_data.char_id
-- and returns the cell state plus the OWNER's user_id (for cross-server lookup).
-- The original SP filters by `id = @user_id` (i.e. the houseobject id matches a
-- char_id). We keep the join semantics verbatim.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseinstant(INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_gethouseinstant(
    _user_id INTEGER
)
RETURNS TABLE (
    out_state       SMALLINT,
    out_permission  SMALLINT,
    out_inwall      INTEGER,
    out_infloor     INTEGER,
    out_user_id     TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT hi.state, hi.permission, hi.inwall, hi.infloor, ud.user_id
      FROM house_instant hi
      JOIN user_data ud ON ud.char_id = hi.id
     WHERE hi.id = _user_id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_gethouseinstant(INTEGER);
-- +goose StatementEnd
