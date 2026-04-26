-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: get_accountid.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION get_accountid(_inuserid TEXT, _charid INTEGER, _accountid INTEGER, _result INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql AS $$
BEGIN
SELECT char_id,_accountid=account_id INTO _charid from user_data with(nolock)

where user_id=_inuserid and delete_complete_date=0

--Result:0,角色ID，角色帐号ID存在，1,角色ID，角色帐号ID不存在, -1,其他错误

if(@_r_o_w_c_o_u_n_t=1)

    BEGIN

        _result := 0

        RETURN  

    END

else

    BEGIN 

         _result := 1

         RETURN

    END



if @_e_r_r_o_r<>0

   BEGIN

        _result := -1

        RETURN

   END /* LIMIT 1 appended */ LIMIT 1;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS get_accountid;
-- +goose StatementEnd
