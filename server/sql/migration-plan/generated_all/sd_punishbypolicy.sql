-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: sd_PunishByPolicy.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION sd_punishbypolicy(_character__i_d INTEGER, _punish__type INTEGER, _punish__policy TEXT)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
SET XACT_ABORT ON;



DECLARE _return__value	int,	--//返回值

		_account__i_d		int,	--//Account ID

		_punish__code	int,	--//1：永久;50：短期;100：角色限制移动;101：角色聊天限制;102：个人商城限制

		_play__block		tinyint,--//1：不能登录；0：能登录

		_punish__min		int,	--//封停分钟

		_punish__reason	nvarchar(200), --//封停原因，会显示在界面上

		_punish__times	int		--//封停次数（同一种封停策略第几次封停）



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



--SELECT COUNT(*) + 1

-- INTO _punish__times	FROM User_Punishment

--	WHERE Char_ID = _character__i_d

--	AND Login_ID = CAST(_punish__policy AS nvarchar(10));

--

--SELECT Punish_Code,

--		_play__block = Play_Block,

--		_punish__min = Punish_Minute,

--		_punish__reason = Punish_Reason

-- INTO _punish__code	FROM sd_Punish_Policy

--	WHERE Policy_ID = _punish__policy

--	AND _punish__times BETWEEN Start_Times AND End_Times;



SELECT Punish_Code,

		_play__block = Play_Block,

		_punish__min = Punish_Minute,

		_punish__reason = Punish_Reason INTO _punish__code

	FROM sd_Punish_Type

	WHERE Punish_Type = _punish__type;



IF @_r_o_w_c_o_u_n_t = 0

BEGIN

	_return__value := -900003;

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

		'(' + _punish__policy + ')(' + CAST(_punish__type AS nvarchar(10)) + ')');

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
DROP FUNCTION IF EXISTS sd_punishbypolicy;
-- +goose StatementEnd
