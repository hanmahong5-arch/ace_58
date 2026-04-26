-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_InitInstanceCooltime_170817.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_initinstancecooltime_170817()
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
BEGIN	


 

	--DELETE FROM 

	--	user_instance 

	--WHERE 

	--	count_variate <= 0 AND 

	--	world_id NOT IN (302450000, 300360000, 302320000, 302390000, 300450000) -- 도전의 탑, 제3템페르훈련소 : 고독의투기장(1vs1), 1vs1 토너먼트 로비, 파티토너먼트 로비

	DELETE FROM user_instance WHERE reentrance_time < (GetUnixtimeWithUTCAdjust((NOW() AT TIME ZONE 'UTC'),0) - 8 * 3600)


END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_initinstancecooltime_170817;
-- +goose StatementEnd
