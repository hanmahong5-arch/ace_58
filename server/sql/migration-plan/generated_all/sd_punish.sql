-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: sd_Punish.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION sd_punish(_character__i_d INTEGER, _punish__policy TEXT, _punish__code INTEGER, _play__block INTEGER, _punish__min INTEGER, _punish__reason TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
SET XACT_ABORT ON;



DECLARE _return__value	int,	--//返回值

		_account__i_d		int		--//Account ID



IF XACT_STATE() = -1

BEGIN

	_return__value := -900001;

	GOTO ErrorHandler;

END



--查找对应的封停帐号ID

SELECT Account_ID INTO _account__i_d

	FROM User_Data WITH(NOLOCK)

	WHERE Char_ID = _character__i_d;



IF @_r_o_w_c_o_u_n_t = 0

BEGIN

	_return__value := -900002;

	GOTO ErrorHandler;

END

	

--封停帐号

BEGIN TRY	

INSERT INTO User_Punishment

	(Account_ID,

	Char_ID,

	Play_Block,

	Status,

	Punish_Code,

	Start_Date,

	End_date,

	Remain_Minute,

	Punish_Reason,

	Login_ID,

	Login_Nm) 

VALUES (_account__i_d,

		_character__i_d,

		_play__block,

		0,

		_punish__code,

		NOW(),

		DATEADD(minute, _punish__min, NOW()), 

		_punish__min, 

		_punish__reason,

		'punish_ur',

		'(' + _punish__policy + ')(-1)');

END TRY

BEGIN CATCH

	_return__value := -900004;

	GOTO ErrorHandler;

END CATCH;

	

RETURN 0;



ErrorHandler:

IF XACT_STATE() <> 0

	ROLLBACK TRANSACTION;

RETURN _return__value;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS sd_punish;
-- +goose StatementEnd
