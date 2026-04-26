-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDAO_InsertUpdateChargePoint.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemdao_insertupdatechargepoint(_id BIGINT, _charge_point INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN



	IF NOT EXISTS ( SELECT id FROM user_item_charge WHERE id = _id )

	BEGIN

		INSERT INTO user_item_charge

		(

			id,

			charge_point

		)

		VALUES

		(

			_id,

			_charge_point

		)

	END

	ELSE

	BEGIN

		UPDATE	user_item_charge

		SET		charge_point = _charge_point

		WHERE	id = _id

	END



	RETURN @_r_o_w_c_o_u_n_t



END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemdao_insertupdatechargepoint;
-- +goose StatementEnd
