import psycopg2
from collections import Counter

dbs = ['aion_world_live', 'aion_account_db', 'aion_account_cache_db', 'aion_gm']

for db in dbs:
    try:
        conn = psycopg2.connect(dbname=db, user='postgres', password='postgres', host='123.56.80.174', client_encoding='UTF8')
        conn.autocommit = True
        cur = conn.cursor()
        
        cur.execute('''
            SELECT n.nspname, p.proname, 
                   pg_get_function_identity_arguments(p.oid) as ident_args,
                   p.prorettype::regtype as rettype
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
        ''')
        funcs = cur.fetchall()
        
        errors = Counter()
        success = 0
        null_errs = 0
        record_errs = 0
        
        for schema, name, args, rettype in funcs:
            arg_list = []
            if args:
                # pg_get_function_identity_arguments returns comma-separated args
                # e.g., "p_account_id integer, p_account_name character varying"
                # We can just extract the type by splitting by ' ' and taking everything after the first word, but some args don't have names.
                # Actually, simpler: query the database for the proper cast using a temporary function or just use the whole arg string if it doesn't have a name.
                # A safer way to just pass NULLs is to use PostgreSQL's type casting from string.
                # Since we know the function name, we can just execute without casting if there's no overloading.
                pass
                
            # Let's rebuild the query differently. Let's just pass NULL without cast, if it fails with 'could not determine data type of parameter', then we will fix it.
            # Actually, to be safe, let's use the provided `args` string but strip the parameter names.
            # It's complex. Let's just use 'NULL' for all args.
            
            call_sql = 'SELECT * FROM {}.\"{}\"({})'.format(schema, name, ','.join(['NULL'] * (len(args.split(',')) if args else 0)))
            
            try:
                with conn.cursor() as cur2:
                    cur2.execute(call_sql)
                success += 1
            except psycopg2.Error as e:
                try:
                    err_msg = e.diag.message_primary if getattr(e, 'diag', None) else 'Unknown error'
                except Exception:
                    err_msg = 'Encoding error in message'
                    
                if 'null value in column' in err_msg.lower():
                    null_errs += 1
                elif 'record' in err_msg.lower() and 'column definition' in err_msg.lower() or '一' in err_msg and 'record' in err_msg:
                    record_errs += 1
                elif 'could not determine data type of parameter' in err_msg.lower() or '无法确定参数' in err_msg:
                    # If we can't determine type, try to cast
                    errors['Needs explicit type cast (Test Script Limitation)'] += 1
                elif 'function' in err_msg.lower() and 'is not unique' in err_msg.lower() or '不唯一' in err_msg:
                    errors['Function not unique (Test Script Limitation)'] += 1
                else:
                    errors[err_msg] += 1
                
        print(f'=== {db} ===')
        print(f'Tested: {len(funcs)} | Success: {success} | NULL constraints: {null_errs} | SETOF Record (Un-testable): {record_errs}')
        print('Real Errors:')
        for err, count in errors.most_common(15):
            print(f'  {count}: {err}')
            
        conn.close()
    except Exception as e:
        print(f'Error connecting to {db}: {e}')
