-- AionCore 5.8 — admin_users table backing the cmd/admin REST API JWT login.
--
-- Replaces the in-memory user store (cmd/admin/auth.go defaultUsers()) which
-- lived only as a development crutch. The hard-coded approach was acceptable
-- when admin/ shipped no real privilege-escalating endpoints; with PG SP
-- wiring landing in priority-50 (player ban / kick / mail / ATM ops), admin
-- becomes a security-critical surface and needs a persistent, ops-mutable,
-- audit-friendly user store.
--
-- Why a dedicated table (not an "admin role" flag on user_data):
--   - admin_users principals are GMs, not players — they never log into the
--     game client, never have a char_id, never own items/guilds. Putting them
--     in user_data would cross-contaminate the player namespace and the SQL
--     audit trails.
--   - The 1063 existing aion_world_live SPs operate on user_data; mixing in
--     "admin role" predicates would force a touch-everywhere refactor.
--
-- Schema decisions:
--   - login is the PK (no surrogate id) — admin team is ≤10 GMs, login is the
--     stable identifier exposed to ops. JWT subject == login keeps audit
--     traces self-explanatory.
--   - pass_hash is the full bcrypt-encoded string ($2a$<cost>$<22-salt><31-hash>),
--     not the raw bytes; that's the standard bcrypt portable representation
--     and survives client/lib swaps.
--   - role is a CHECK-constrained text rather than an enum because adding a
--     new role (e.g. 'auditor', 'support') is a routine ops change and we
--     don't want to ship a migration just to extend an enum's variants.
--   - disabled keeps disabled accounts in the table for audit (we never
--     DELETE; we flip disabled = true). Rotation policies / re-hire scenarios
--     keep the historical record intact.
--   - last_login is informational; the auth path UPDATEs it after a
--     successful bcrypt compare.
--
-- The seeded `sadmin` row uses bcrypt cost 12 against plaintext "sadmin-dev-pwd".
-- This MUST be rotated on first login in any environment that persists past
-- a ten-minute smoke. The cmd/admin docs (CLAUDE.md and the loadAuthStore
-- comment) call this out explicitly.

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS admin_users (
    login        text PRIMARY KEY CHECK (length(login) BETWEEN 3 AND 32),
    pass_hash    text NOT NULL CHECK (length(pass_hash) BETWEEN 50 AND 80),
    role         text NOT NULL CHECK (role IN ('superadmin', 'gm', 'readonly')),
    disabled     boolean NOT NULL DEFAULT false,
    created_at   timestamptz NOT NULL DEFAULT now(),
    last_login   timestamptz
);
-- +goose StatementEnd

-- +goose StatementBegin
-- Partial index — covers the hot path "list active GMs by role" without
-- bloating the index against tombstoned accounts.
CREATE INDEX IF NOT EXISTS idx_admin_users_role_active
    ON admin_users(role)
    WHERE NOT disabled;
-- +goose StatementEnd

-- +goose StatementBegin
-- Bootstrap superadmin so a fresh deployment can complete its first login.
-- Plaintext = "sadmin-dev-pwd"; bcrypt cost = 12. Generated via
-- `go test -tags=hashgen ./cmd/admin -run TestGenerateDefaultAdminHash -v`
-- (see cmd/admin/hashgen_test.go). Operators MUST rotate this password
-- before exposing the admin port beyond 127.0.0.1.
INSERT INTO admin_users (login, pass_hash, role)
VALUES (
    'sadmin',
    '$2a$12$8LxxgSypmWj/YJC1M5MVIeCJEitNYQkmQnL8.wEiCfXXuynql9Foi',
    'superadmin'
)
ON CONFLICT (login) DO NOTHING;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS admin_users;
-- +goose StatementEnd
