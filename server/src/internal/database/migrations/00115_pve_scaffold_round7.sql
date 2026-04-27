-- AionCore 5.8 — Sprint 1.1a Round 10 (F1) scaffold for char-lifecycle SPs.
--
-- Round 10 closes the build→list→select→login→logout→delete loop. Most
-- supporting tables (user_data, user_item, user_skill, user_quest,
-- user_finished_quest) are already scaffolded in Rounds 2-6. This migration
-- adds the four side-tables that the cascade-Delete SPs touch but no prior
-- round has needed:
--
--   user_abnormal_status     — buff/debuff persistence (DeleteAllAbnormalStatus)
--   user_emotion             — purchased emote slots (DeleteEmotion)
--   user_familiar            — pet sub-system (DeleteFamiliar; soft delete)
--   user_promotion_cooltime  — daily promo cooldowns (DeleteAllPromotionCoolTime)
--
-- Each table receives the minimum surface the corresponding SP touches.
-- Subsequent rounds will widen them as the rest of the buff / familiar /
-- promo SPs come online (we've ported only the DELETEs in R10 because the
-- delete cascade is on the critical path for character-purge correctness).

-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_abnormal_status (
    char_id            INTEGER     NOT NULL,
    abnormal_id        INTEGER     NOT NULL,
    remain_time_ms     INTEGER     NOT NULL DEFAULT 0,
    casted_time        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (char_id, abnormal_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_emotion (
    char_id            INTEGER     NOT NULL,
    emotion_id         INTEGER     NOT NULL,
    -- emotion_type は分類 (NCSoft 用 smallint; 0=普通, 1=event, 2=GM 賦予)
    emotion_type       SMALLINT    NOT NULL DEFAULT 0,
    expire_time        TIMESTAMPTZ,
    PRIMARY KEY (char_id, emotion_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- user_familiar uses BIGSERIAL because the pet/familiar id space crosses
-- characters (gifting / trading) — same pattern as user_pet (Round 8).
CREATE TABLE IF NOT EXISTS user_familiar (
    id                 BIGSERIAL   PRIMARY KEY,
    char_id            INTEGER     NOT NULL,
    familiar_template_id INTEGER   NOT NULL DEFAULT 0,
    name               TEXT        NOT NULL DEFAULT '',
    level              INTEGER     NOT NULL DEFAULT 1,
    exp                BIGINT      NOT NULL DEFAULT 0,
    -- soft-delete flag preserved verbatim from NCSoft schema
    deleted            SMALLINT    NOT NULL DEFAULT 0,
    update_time        BIGINT      NOT NULL DEFAULT 0
);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE INDEX IF NOT EXISTS idx_user_familiar_char ON user_familiar(char_id);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS user_promotion_cooltime (
    char_id            INTEGER     NOT NULL,
    promotion_id       SMALLINT    NOT NULL,
    next_avail_time    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (char_id, promotion_id)
);
-- +goose StatementEnd

-- +goose StatementBegin
-- user_item.update_date — DeleteItemByChar uses GETDATE() to bump it when
-- archiving items to warehouse 10 (the soft-delete sink). Round 2 scaffolded
-- user_item without it because DeleteItem (00019) operates by id and does
-- not need wall-clock; Round 10's per-char wipe does.
ALTER TABLE user_item
    ADD COLUMN IF NOT EXISTS update_date TIMESTAMPTZ NOT NULL DEFAULT NOW();
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE user_item DROP COLUMN IF EXISTS update_date;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_promotion_cooltime;
-- +goose StatementEnd

-- +goose StatementBegin
DROP INDEX IF EXISTS idx_user_familiar_char;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_familiar;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_emotion;
-- +goose StatementEnd

-- +goose StatementBegin
DROP TABLE IF EXISTS user_abnormal_status;
-- +goose StatementEnd
