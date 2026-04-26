-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.
-- Source file: aion_dbreindex_all.sql
-- Review TODOs before deploying.

-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION aion_dbreindex_all(_fillfactor INTEGER)
RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
-- TODO: unsupported T-SQL construct: CURSOR
-- TODO: unsupported T-SQL construct: FETCH
-- TODO: unsupported T-SQL construct: OPEN
-- TODO: unsupported T-SQL construct: CLOSE
-- TODO: unsupported T-SQL construct: DEALLOCATE




DECLARE _table VARCHAR(255) 

DECLARE _cmd NVARCHAR(500) 



BEGIN

   _cmd := 'DECLARE TableCursor CURSOR FOR select name from sys.all_objects where type_desc=''USER_TABLE'' and is_ms_shipped=0'

   EXEC (_cmd) 

   OPEN TableCursor  



   FETCH NEXT FROM TableCursor INTO _table  

   WHILE @_f_e_t_c_h__s_t_a_t_u_s = 0  

   BEGIN         

       _cmd := 'ALTER INDEX ALL ON ' + _table + ' REBUILD WITH (FILLFACTOR = ' +

               CONVERT(VARCHAR(3),_fillfactor) + ')' 
RAISE NOTICE '%', _cmd + ' -- applied.'       ;

       EXEC (_cmd) 

       FETCH NEXT FROM TableCursor INTO _table  

   END  



   CLOSE TableCursor  

   DEALLOCATE TableCursor   

END;
END;
$$;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS aion_dbreindex_all;
-- +goose StatementEnd
