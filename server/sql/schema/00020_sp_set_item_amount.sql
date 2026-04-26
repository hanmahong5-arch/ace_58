-- AionCore 5.8 — Sprint 1.1a Round 5 port: aion_SetItemAmount.
--
-- Used after consumable potion/scroll consumption to update stack count.
-- T-SQL body is a single UPDATE.

-- +goose Up
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemamount(BIGINT, BIGINT);
-- +goose StatementEnd

-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemamount(_id BIGINT, _amount BIGINT)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE user_item SET amount = _amount WHERE id = _id;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemamount(BIGINT, BIGINT);
-- +goose StatementEnd
