-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_GetVendorAverageLight.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_getvendoraveragelight(_make_date INTEGER, _get_only_oneweek INTEGER)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: CLOSE
-- TODO: unsupported T-SQL construct: DEALLOCATE


BEGIN




	-- SELECT name_id, sold_unit_price, sold_date FROM vendor_average_light;

	

	-- SELECT * FROM A FULL OUTER JOIN B WHERE A.name_id = B.name_id;

	-- SELECT name_id, averge_unit_price, entire_sold_number FROM vendor_average_light_last_result WHERE create_date > _date_from;

	-- SELECT name_id, AVG(sold_unit_price), COUNT(*) FROM vendor_average_light GROUP BY name_id;

	

	-- BEGIN TRAN;

	

	DECLARE _cursqldate DATETIME = NOW();

	

	DECLARE _name_id BIGINT;

	DECLARE _avg BIGINT;

	DECLARE _num INT;



	DECLARE _last_avg BIGINT;

	DECLARE _last_num INT;

	DECLARE _last_date INT;



	-- calculate average from log, log tbl will be truncated		

	DECLARE cur_log CURSOR FOR (SELECT name_id, AVG(sold_unit_price), COUNT(*) FROM vendor_average_light WHERE sold_date < _make_date GROUP BY name_id);

	OPEN cur_log;

	FETCH NEXT FROM cur_log INTO _name_id, _avg, _num;

	

	WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0

	BEGIN

		-- find last average

		SELECT average_unit_price, _last_num = entire_sold_number, _last_date = create_date INTO _last_avg FROM vendor_average_light_last_result WHERE name_id = _name_id;

		

		IF _last_avg IS NULL

		BEGIN

			-- new sold average

			INSERT vendor_average_light_last_result (name_id, average_unit_price, entire_sold_number, create_date, update_date)

			VALUES (_name_id, _avg, _num, _make_date, _make_date);

		END

		ELSE

		BEGIN

		/* changes: just make average one week, not all before make time

			IF (_last_date > _make_date)

			BEGIN

				-- update last average

				UPDATE vendor_average_light_last_result

				SET average_unit_price = (((_last_num * _last_avg) + (_num * _avg)) / (_last_num + _num)), entire_sold_number = _last_num + _num, update_date = _make_date, update_datetime = _cursqldate

				WHERE name_id = _name_id;

			END

			ELSE

			BEGIN

		*/

				-- replace old average to new

				UPDATE vendor_average_light_last_result 

				SET average_unit_price = _avg, entire_sold_number = _num, update_date = _make_date, update_datetime = _cursqldate

				WHERE name_id = _name_id;

		/*

			END

		*/			

		END

		

		FETCH NEXT FROM cur_log INTO _name_id, _avg, _num;

	END

	CLOSE cur_log;

	DEALLOCATE cur_log;

	

	-- COMMIT TRAN

	

	-- DELETE FROM completed sold log

	DELETE FROM vendor_average_light WHERE sold_date < _make_date;

	

	-- select result to server

	IF (_get_only_oneweek > 0)

	BEGIN

		SELECT name_id, average_unit_price FROM vendor_average_light_last_result WHERE update_date = _make_date;

	END

	ELSE

	BEGIN

		SELECT name_id, average_unit_price FROM vendor_average_light_last_result;

	END

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_getvendoraveragelight;
-- +goose StatementEnd
