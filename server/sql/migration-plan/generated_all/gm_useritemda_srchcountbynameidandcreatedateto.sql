-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: GM_UserItemDA_SrchCountByNameIdAndCreateDateTo.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION gm_useritemda_srchcountbynameidandcreatedateto(_name_id INTEGER, _create_date_to TEXT)
RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)
LANGUAGE plpgsql AS $$
BEGIN
set transaction isolation level read uncommitted

			

			declare _vendor_log_dark_qina	bigint

			declare _vendor_log_light_qina	bigint

			declare _guild_fund bigint

			_vendor_log_dark_qina := 0

			_vendor_log_light_qina := 0

			_guild_fund := 0

			

			if (_create_date_to = '')

			begin

				if (_name_id = 182400001)

				begin

					SELECT COALESCE(SUM(sold_price), 0) INTO _vendor_log_dark_qina from vendor_log_dark (nolock)

					select	_vendor_log_light_qina = COALESCE(SUM(sold_price), 0) from vendor_log_light (nolock)

					select	_guild_fund = COALESCE(SUM(fund), 0) from guild (nolock)

				end

				

				select	(SUM(amount) + _vendor_log_dark_qina + _vendor_log_light_qina + _guild_fund) as total_amount, name_id

				from	user_item (nolock)

				where	name_id = _name_id

				and		(warehouse in (0,1,3,4,5,6,7) OR (warehouse between 30 and 49) OR (warehouse between 60 and 79))

				group by name_id

			end

			else

			begin

				if (_name_id = 182400001)

				begin

					select	_vendor_log_dark_qina = COALESCE(SUM(sold_price), 0) from vendor_log_dark (nolock) where sold_date <= datediff(mi, '1970-01-01 09:00', _create_date_to)

					select	_vendor_log_light_qina = COALESCE(SUM(sold_price), 0) from vendor_log_light (nolock) where sold_date <= datediff(mi, '1970-01-01 09:00', _create_date_to)

					select	_guild_fund = COALESCE(SUM(fund), 0) from guild (nolock)

				end

								

				select	(SUM(amount) + _vendor_log_dark_qina + _vendor_log_light_qina + _guild_fund) as total_amount, name_id

				from	user_item (nolock)

				where	name_id = _name_id

				and		(warehouse in (0,1,3,4,5,6,7) OR (warehouse between 30 and 49) OR (warehouse between 60 and 79))

				and		create_date <= _create_date_to

				group by name_id

			end;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS gm_useritemda_srchcountbynameidandcreatedateto;
-- +goose StatementEnd
