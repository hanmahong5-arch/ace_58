-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_SetItemExpiredTime.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_setitemexpiredtime(_d_b_id BIGINT, _expired_time INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
DECLARE _t_t_l int

	DECLARE _result int

	SELECT Expired_Time INTO _t_t_l FROM user_item(updlock) WHERE id = _d_b_id

	

	-- if the 'time to live' is positive, the timer has already been activated.

	IF _t_t_l >= 0 RETURN _t_t_l



	_result := _expired_time - _t_t_l

	UPDATE user_item SET Expired_Time = _result WHERE id = _d_b_id



	RETURN _result;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_setitemexpiredtime;
-- +goose StatementEnd
