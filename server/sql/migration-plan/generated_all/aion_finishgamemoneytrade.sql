-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_FinishGameMoneyTrade.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_finishgamemoneytrade(_request_id TEXT, _event_type INTEGER, _seller INTEGER, _buyer INTEGER, _state INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
BEGIN


	declare _id bigint

	declare _buyer int

	declare _reward_seller tinyint

	

	_state := 0	--존재하지 않는 항목일 경우, 아래 if문에 의해서 _state가 세팅되지 않고 반환되는 것을 미리 막기

	

	SELECT id, _state=state, _buyer=COALESCE(buyer, 0), _reward_seller=COALESCE(reward_seller, 0) INTO _id From game_money_trade with (nolock) Where request_id=_request_id and state=1;



	If _id<>0

	Begin

		if _event_type = 1

		begin 

			if _seller <> 0 and _buyer = 0 and _buyer = 0		-- 거래 완료, 판매쪽 처리 중, 구매쪽 처리 미완료

				Update game_money_trade with (updlock) set reward_seller=1 Where id=_id;

			else if _seller <> 0 and _buyer = 0 and _buyer <> 0	-- 거래 완료, 판매쪽 처리 중, 구매쪽 처리 완료

				Update game_money_trade with (updlock) set state=2, complete_date=NOW(), reward_seller=1 Where id=_id;

			else if _seller = 0 and  _buyer <> 0 and _reward_seller = 0	-- 거래 완료, 구매쪽 처리 중, 판매쪽 처리 미완료

				Update game_money_trade with (updlock) set buyer=_buyer Where id=_id;

			else if _seller = 0 and _buyer <> 0 and _reward_seller = 1	-- 거래 완료, 구매쪽 처리 중, 판매쪽 처리 완료

				Update game_money_trade with (updlock) set state=2, complete_date=NOW(), buyer=_buyer Where id=_id;

		end

		else if _event_type = 2

		begin

			if _seller <> 0

				Update game_money_trade with (updlock) set state=-1, complete_date=NOW() Where id=_id;

		end

		else if _event_type = 3	-- 판매 취소는 거래가 진행되지 않았을 때만 허용함

		begin

			if _seller <> 0 and _state = 1 and _reward_seller = 0

				Update game_money_trade with (updlock) set state=-2, complete_date=NOW() Where id=_id;

		end

		else if _event_type = 4	-- 구매 실패라고 해도 판매자에게 보상 가기 전까지만 허용함

		begin

			if _buyer <> 0 and _state = 1 and _buyer <> 0 and _reward_seller=0

				Update game_money_trade with (updlock) set state=-3, complete_date=NOW() Where id=_id;

		end

	

		If @_r_o_w_c_o_u_n_t = 1

		begin

			SELECT state INTO _state From game_money_trade with (nolock) Where id=_id

			return 0

		end

		Else

			return -2 -- Fail to update

	End

	Else

	Begin

		return -1	-- Can't find 

	End

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_finishgamemoneytrade;
-- +goose StatementEnd
