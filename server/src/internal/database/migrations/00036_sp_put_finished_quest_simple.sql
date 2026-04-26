-- AionCore 5.8 — Sprint 1.1a Round 6 (Track B4) port: aion_putFinishedQuestSimple.
--
-- Source: ai/wiki/raw/47104-sp-dump/AionWorldLive/procedures/aion_putFinishedQuestSimple.sql
-- Inserts a row into user_finished_quest when the player completes a quest.
-- T-SQL form is a bare INSERT; PG translation uses ON CONFLICT DO NOTHING so
-- replays during boot-time fixup don't blow up the (char_id, quest_id, branch)
-- composite PK. Repeat-quest logic (incrementing repeat_quest_count) is the
-- responsibility of a separate SP not yet ported (aion_PutFinishedQuestEx_*).

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfinishedquestsimple(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_putfinishedquestsimple(
    _charid   INTEGER,
    _quest_id INTEGER,
    _branch   INTEGER
) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_finished_quest
        (char_id, quest_id, quest_count, quest_branch, quest_finishedtime, repeat_quest_count)
    VALUES (_charid, _quest_id, 1, _branch::SMALLINT, 0, 1)
    ON CONFLICT (char_id, quest_id, quest_branch) DO NOTHING;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_putfinishedquestsimple(INTEGER, INTEGER, INTEGER);
-- +goose StatementEnd
