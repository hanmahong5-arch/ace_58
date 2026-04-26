-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetCharInGameBlockPunishInfo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getcharingameblockpunishinfo(_char_i_d INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
select Punish_Code,  Remain_Minute, Punish_Reason 

from User_Punishment 

where char_id = _char_i_d and Play_Block = 0 and Status = 0 and Remain_Minute > 0 and Punish_Code >= 100

order by Punish_Code;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getcharingameblockpunishinfo;
-- +goose StatementEnd
