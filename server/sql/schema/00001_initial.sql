-- AionCore 5.8 — Initial schema migration (Sprint -1 Track B).
--
-- Bootstrap migration that:
--   1. Enables pgcrypto for randomness used by future SP migrations.
--   2. Deploys aion_get_server_time() — the hello-world SP that proves the
--      end-to-end Go ↔ goose ↔ PG ↔ CallSP() pipeline is wired correctly.
--
-- Per dev-guide.md three-layer rule: business logic lives in PL/pgSQL SPs,
-- not in Go. This file is the gate for Sprint 1.1a (T-SQL → PG SP port of
-- the 50 NCSoft core stored procedures).

-- +goose Up
-- +goose StatementBegin
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE SQL
STABLE
AS $$
    SELECT now();
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_get_server_time();
-- +goose StatementEnd
