#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Analyze all deploy failures and runtime errors in detail"""

import psycopg2
import json
import re
import os

DB_CONFIG = {'host': '123.56.80.174', 'port': 5432, 'user': 'postgres', 'password': 'postgres'}
PROC_DIR = 'procedures'
DB_MAP = {
    'aion_world_live': 'aion_world_live_procedures.sql',
    'aion_account_db': 'aion_account_db_procedures.sql',
    'aion_account_cache_db': 'aion_account_cache_db_procedures.sql',
    'aion_gm': 'aion_gm_procedures.sql',
}

def get_deploy_failures():
    """Get all functions that fail to deploy with their error messages"""
    all_errors = []
    for dbname, sql_file in DB_MAP.items():
        filepath = os.path.join(PROC_DIR, sql_file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Split by $$ delimiter (dollar quoting)
        functions = re.findall(
            r'(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+.*?\$\$;)',
            content, re.DOTALL
        )

        conn = psycopg2.connect(dbname=dbname, **DB_CONFIG)
        conn.autocommit = True
        cur = conn.cursor()

        ok = 0
        fail = 0
        for func_sql in functions:
            m = re.search(r'FUNCTION\s+(\w+)\s*\(', func_sql)
            fname = m.group(1) if m else 'unknown'
            try:
                cur.execute(func_sql)
                ok += 1
            except Exception as e:
                fail += 1
                err_msg = str(e).replace('\n', ' | ')[:400]
                all_errors.append({
                    'db': dbname,
                    'func': fname,
                    'error': err_msg,
                    'sql_preview': func_sql[:200]
                })

        print(f"{dbname}: {ok} ok, {fail} fail (total {len(functions)})")
        cur.close()
        conn.close()

    return all_errors


def get_runtime_failures():
    """Get all functions that fail at runtime with NULL params"""
    CALLABLE_ERRORS = {'23502', 'P0001', '22004', '2F005', '22P02', '23503', '23514', '42725'}

    all_errors = []
    for dbname in DB_MAP:
        conn = psycopg2.connect(dbname=dbname, **DB_CONFIG)
        conn.autocommit = False
        cur = conn.cursor()

        # Get all functions
        cur.execute("""
            SELECT r.routine_name,
                   count(p.parameter_name) as pcount,
                   r.specific_name
            FROM information_schema.routines r
            LEFT JOIN information_schema.parameters p
                ON r.specific_name = p.specific_name AND p.parameter_mode IN ('IN', 'INOUT')
            WHERE r.routine_schema = 'public' AND r.routine_type = 'FUNCTION'
            GROUP BY r.routine_name, r.specific_name
        """)
        funcs = cur.fetchall()

        # Get return types
        cur.execute("""
            SELECT p.proname, p.prorettype::regtype::text,
                   pg_get_function_identity_arguments(p.oid)
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
        """)
        func_info = {}
        for pname, rettype, args in cur.fetchall():
            has_out = 'OUT ' in (args or '')
            func_info[pname] = {'rettype': rettype, 'has_out': has_out}

        for fname, pcount, specific in funcs:
            try:
                null_args = ', '.join(['NULL'] * (pcount or 0))
                info = func_info.get(fname, {'rettype': '', 'has_out': False})
                rettype = info['rettype']
                has_out = info['has_out']
                if ('SETOF' in rettype or rettype == 'record') and not has_out:
                    sql = f'SELECT * FROM {fname}({null_args}) AS t(c text)'
                else:
                    sql = f'SELECT {fname}({null_args})'
                cur.execute(sql)
                cur.fetchall()
                conn.rollback()
            except Exception as e:
                conn.rollback()
                code = e.pgcode if hasattr(e, 'pgcode') else 'unknown'
                if code in CALLABLE_ERRORS:
                    continue
                if code == '0A000' and 'materialize' in str(e).lower():
                    continue
                if code == '42804' and 'structure of query' in str(e).lower():
                    continue
                if code == '42601' and ('column definition' in str(e).lower() or 'RETURN QUERY' in str(e)):
                    continue

                err_msg = str(e).replace('\n', ' | ')[:300]
                all_errors.append({
                    'db': dbname,
                    'func': fname,
                    'code': code,
                    'error': err_msg
                })

        cur.close()
        conn.close()

    return all_errors


if __name__ == '__main__':
    print("=" * 60)
    print("DEPLOY FAILURES")
    print("=" * 60)
    deploy_errors = get_deploy_failures()

    # Categorize deploy errors
    deploy_cats = {}
    for err in deploy_errors:
        msg = err['error']
        if 'END IF' in msg or 'ELSE' in msg and 'block' not in msg:
            cat = 'IF_ELSE_MISMATCH'
        elif '括号不匹配' in msg:
            cat = 'UNBALANCED_PARENS'
        elif '输入的末尾' in msg:
            cat = 'UNEXPECTED_EOF'
        elif '已知变量' in msg:
            cat = 'UNKNOWN_VARIABLE'
        elif 'RETURN' in msg:
            cat = 'RETURN_SYNTAX'
        else:
            cat = 'OTHER'
        deploy_cats.setdefault(cat, []).append(err)

    print(f"\nTotal deploy failures: {len(deploy_errors)}")
    for cat, errs in sorted(deploy_cats.items(), key=lambda x: -len(x[1])):
        print(f"\n{cat}: {len(errs)}")
        for e in errs[:3]:
            print(f"  {e['db']}.{e['func']}")
            print(f"    {e['error'][:200]}")

    print("\n" + "=" * 60)
    print("RUNTIME FAILURES (real, not callable)")
    print("=" * 60)
    runtime_errors = get_runtime_failures()

    # Categorize runtime errors
    runtime_cats = {}
    for err in runtime_errors:
        code = err['code']
        msg = err['error']
        if code == '42883':
            if '操作符' in msg or 'operator' in msg.lower():
                cat = '42883_OPERATOR'
            else:
                cat = '42883_FUNCTION'
        elif code == '42P01':
            cat = '42P01_TABLE'
        elif code == '42846':
            cat = '42846_CAST'
        elif code == '42703':
            cat = '42703_COLUMN'
        elif code == '42712':
            cat = '42712_DUP_ALIAS'
        elif code == '3F000':
            cat = '3F000_SCHEMA'
        elif code == '42704':
            cat = '42704_TYPE'
        else:
            cat = f'{code}_OTHER'
        runtime_cats.setdefault(cat, []).append(err)

    print(f"\nTotal runtime failures: {len(runtime_errors)}")
    for cat, errs in sorted(runtime_cats.items(), key=lambda x: -len(x[1])):
        print(f"\n{cat}: {len(errs)}")
        for e in errs[:3]:
            print(f"  {e['db']}.{e['func']}: {e['error'][:180]}")
        if len(errs) > 3:
            print(f"  ... +{len(errs)-3} more")

    # Save full results
    results = {
        'deploy_failures': deploy_errors,
        'runtime_failures': runtime_errors,
        'deploy_categories': {k: len(v) for k, v in deploy_cats.items()},
        'runtime_categories': {k: len(v) for k, v in runtime_cats.items()}
    }
    with open('procedures/failure_analysis.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nFull analysis saved to procedures/failure_analysis.json")
