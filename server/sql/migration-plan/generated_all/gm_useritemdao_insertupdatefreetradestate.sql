-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertUpdateFreeTradeState.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertupdatefreetradestate(_id BIGINT, _name_id INTEGER, _freetradestate INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN

			update user_item_freetrade set freeTradeState=_freetradestate where id=_id

			if (0 < @_r_o_w_c_o_u_n_t)

			begin

				return 1

			end

			else

			begin

				if (_freetradestate != 0)

					insert into user_item_freetrade (id, name_id, freeTradeState) values (_id, _name_id, _freetradestate)

				else

					return 1

			end

		END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertupdatefreetradestate;
-- +goose StatementEnd
