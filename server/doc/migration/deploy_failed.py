#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Deploy previously failed stored procedures to PostgreSQL.
Reads the failed function list from deploy_errors.json,
extracts the regenerated SQL from procedure files,
and deploys them one by one to the target databases.
"""

import json
import re
import os
import sys
import time
import psycopg2
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ERRORS_FILE = os.path.join(SCRIPT_DIR, "procedures", "deploy_errors.json")
PROC_DIR = os.path.join(SCRIPT_DIR, "procedures")

# Database connection config
DB_CONFIG = {
    "host": "123.56.80.174",
    "port": 5432,
    "user": "postgres",
    "password": "postgres",
}

# Map database names to SQL files
DB_FILE_MAP = {
    "aion_world_live": "aion_world_live_procedures.sql",
    "aion_account_db": "aion_account_db_procedures.sql",
    "aion_account_cache_db": "aion_account_cache_db_procedures.sql",
    "aion_gm": "aion_gm_procedures.sql",
}


def extract_function_sql(sql_content: str, func_name: str) -> str:
    """Extract a single function's CREATE OR REPLACE statement from the SQL file"""
    # Search for the function definition
    pattern = rf'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+{re.escape(func_name)}\s*\('
    match = re.search(pattern, sql_content, re.IGNORECASE)
    if not match:
        return None

    start = match.start()

    # Find the end: look for $$; which ends the function
    # We need to find the matching $$; after the opening $$
    pos = sql_content.find('$$', start)
    if pos == -1:
        return None

    # Find the closing $$;
    end_marker = sql_content.find('$$;', pos + 2)
    if end_marker == -1:
        return None

    return sql_content[start:end_marker + 3]


def deploy_function(conn, func_sql: str, func_name: str) -> tuple:
    """Deploy a single function. Returns (success: bool, error: str)"""
    try:
        with conn.cursor() as cur:
            cur.execute(func_sql)
        conn.commit()
        return True, None
    except Exception as e:
        conn.rollback()
        return False, str(e).strip()


def main():
    # Load previous errors
    with open(ERRORS_FILE, 'r', encoding='utf-8') as f:
        error_data = json.load(f)

    failed_funcs = error_data['errors']
    print(f"Previously failed functions: {len(failed_funcs)}")

    # Load all SQL files into memory
    sql_contents = {}
    for db_name, sql_file in DB_FILE_MAP.items():
        path = os.path.join(PROC_DIR, sql_file)
        if os.path.exists(path):
            with open(path, 'r', encoding='utf-8') as f:
                sql_contents[db_name] = f.read()
        else:
            print(f"WARNING: {sql_file} not found")

    # Group failures by database
    by_db = {}
    for item in failed_funcs:
        db = item['database']
        if db not in by_db:
            by_db[db] = []
        by_db[db].append(item['function'])

    # Deploy
    results = {
        'deploy_time': datetime.now().isoformat(),
        'target_host': f"{DB_CONFIG['host']}:{DB_CONFIG['port']}",
        'round': 'redeploy_failed',
        'previous_failures': len(failed_funcs),
        'summary': {},
        'new_successes': [],
        'still_failing': [],
    }

    total_success = 0
    total_fail = 0

    for db_name, func_list in by_db.items():
        print(f"\n--- Deploying to {db_name} ({len(func_list)} functions) ---")

        if db_name not in sql_contents:
            print(f"  SKIP: no SQL file for {db_name}")
            for fn in func_list:
                results['still_failing'].append({
                    'function': fn,
                    'database': db_name,
                    'error': 'No SQL file found'
                })
            total_fail += len(func_list)
            continue

        sql_content = sql_contents[db_name]

        try:
            conn = psycopg2.connect(
                host=DB_CONFIG['host'],
                port=DB_CONFIG['port'],
                user=DB_CONFIG['user'],
                password=DB_CONFIG['password'],
                dbname=db_name,
                connect_timeout=10
            )
        except Exception as e:
            print(f"  CONNECTION ERROR: {e}")
            for fn in func_list:
                results['still_failing'].append({
                    'function': fn,
                    'database': db_name,
                    'error': f'Connection error: {str(e)}'
                })
            total_fail += len(func_list)
            continue

        db_success = 0
        db_fail = 0

        for func_name in func_list:
            func_sql = extract_function_sql(sql_content, func_name)
            if func_sql is None:
                results['still_failing'].append({
                    'function': func_name,
                    'database': db_name,
                    'error': 'Function SQL not found in generated file'
                })
                db_fail += 1
                continue

            success, error = deploy_function(conn, func_sql, func_name)
            if success:
                db_success += 1
                results['new_successes'].append({
                    'function': func_name,
                    'database': db_name
                })
            else:
                db_fail += 1
                results['still_failing'].append({
                    'function': func_name,
                    'database': db_name,
                    'error': error
                })

        conn.close()

        total_success += db_success
        total_fail += db_fail
        results['summary'][db_name] = {
            'attempted': len(func_list),
            'success': db_success,
            'fail': db_fail,
        }
        print(f"  Success: {db_success}, Fail: {db_fail}")

    # Summary
    print(f"\n{'='*60}")
    print(f"REDEPLOY RESULTS")
    print(f"{'='*60}")
    print(f"Previously failed: {len(failed_funcs)}")
    print(f"Now succeeded:     {total_success}")
    print(f"Still failing:     {total_fail}")
    fix_rate = total_success / len(failed_funcs) * 100 if failed_funcs else 0
    print(f"Fix rate:          {fix_rate:.1f}%")

    # Overall rate: original total was 1399
    original_success = 1399 - len(failed_funcs)  # 792
    new_total_success = original_success + total_success
    print(f"\nOverall: {new_total_success}/{1399} = {new_total_success/1399*100:.1f}% success rate")

    # Save results
    output_path = os.path.join(PROC_DIR, "redeploy_results.json")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nResults saved to: {output_path}")

    # Update deploy_errors.json with remaining failures
    if results['still_failing']:
        # Categorize errors
        error_cats = {}
        for item in results['still_failing']:
            err = item['error']
            if 'NOLOCK' in err:
                cat = 'SQL Server syntax remnant (NOLOCK)'
            elif 'CAST' in err or 'type' in err.lower() or 'integer' in err:
                cat = 'Type conversion error'
            elif 'Connection' in err or 'connection' in err:
                cat = 'Connection error'
            else:
                cat = 'Other'
            error_cats[cat] = error_cats.get(cat, 0) + 1

        new_errors = {
            'deploy_time': datetime.now().isoformat(),
            'target_host': f"{DB_CONFIG['host']}:{DB_CONFIG['port']}",
            'summary': results['summary'],
            'error_categories': error_cats,
            'total_errors': len(results['still_failing']),
            'errors': results['still_failing'],
        }
        with open(ERRORS_FILE, 'w', encoding='utf-8') as f:
            json.dump(new_errors, f, indent=2, ensure_ascii=False)
        print(f"Updated deploy_errors.json with {len(results['still_failing'])} remaining errors")

    return total_fail


if __name__ == "__main__":
    sys.exit(main())
