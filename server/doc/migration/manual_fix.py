#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Manual Fix Applier for PL/pgSQL Functions
==========================================
Reads fix patches from procedures/patches/ directory and applies them
to the generated SQL files. Each patch is a .sql file named after the
function it fixes, containing the corrected CREATE OR REPLACE FUNCTION.

Usage:
    python manual_fix.py                    # Apply all patches
    python manual_fix.py --deploy           # Deploy patched functions
    python manual_fix.py --deploy --test    # Deploy and test
"""

import psycopg2
import json
import re
import os
import sys
import glob

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROC_DIR = os.path.join(SCRIPT_DIR, "procedures")
PATCH_DIR = os.path.join(PROC_DIR, "patches")

DB_CONFIG = {
    'host': '123.56.80.174',
    'port': 5432,
    'user': 'postgres',
    'password': 'postgres'
}

DB_SQL_MAP = {
    'aion_world_live': 'aion_world_live_procedures.sql',
    'aion_account_db': 'aion_account_db_procedures.sql',
    'aion_account_cache_db': 'aion_account_cache_db_procedures.sql',
    'aion_gm': 'aion_gm_procedures.sql',
}


def load_patches():
    """Load all patch files from the patches directory"""
    patches = {}
    if not os.path.exists(PATCH_DIR):
        os.makedirs(PATCH_DIR)
        return patches

    for patch_file in glob.glob(os.path.join(PATCH_DIR, "*.sql")):
        with open(patch_file, 'r', encoding='utf-8') as f:
            content = f.read().strip()
        if not content:
            continue

        # Extract function name and database from the patch
        # Format: -- database: aion_world_live
        db_match = re.search(r'--\s*database:\s*(\w+)', content)
        func_match = re.search(r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+(\w+)\s*\(', content, re.IGNORECASE)

        if func_match:
            fname = func_match.group(1).lower()
            db = db_match.group(1) if db_match else None
            patches[fname] = {
                'db': db,
                'sql': content,
                'file': os.path.basename(patch_file)
            }

    return patches


def apply_patches_to_files(patches):
    """Replace functions in the SQL files with patched versions"""
    applied = 0
    for dbname, sql_file in DB_SQL_MAP.items():
        filepath = os.path.join(PROC_DIR, sql_file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        modified = False
        for fname, patch in patches.items():
            if patch['db'] and patch['db'] != dbname:
                continue

            # Find the function in the file
            pattern = re.compile(
                r'(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+' + re.escape(fname) + r'\s*\(.*?\$\$;)',
                re.DOTALL | re.IGNORECASE
            )
            match = pattern.search(content)
            if match:
                # Remove the -- database: comment from patch before replacing
                clean_patch = re.sub(r'--\s*database:\s*\w+\s*\n?', '', patch['sql']).strip()
                content = content[:match.start()] + clean_patch + content[match.end():]
                modified = True
                applied += 1
                print(f"  Applied patch: {fname} in {dbname}")

        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)

    return applied


def deploy_patches(patches):
    """Deploy patched functions directly to the database"""
    deployed = 0
    failed = 0
    for fname, patch in patches.items():
        db = patch['db']
        if not db:
            # Try all databases
            dbs = list(DB_SQL_MAP.keys())
        else:
            dbs = [db]

        for dbname in dbs:
            try:
                conn = psycopg2.connect(dbname=dbname, **DB_CONFIG)
                conn.autocommit = True
                cur = conn.cursor()
                clean_sql = re.sub(r'--\s*database:\s*\w+\s*\n?', '', patch['sql']).strip()
                cur.execute(clean_sql)
                cur.close()
                conn.close()
                deployed += 1
                print(f"  Deployed: {fname} -> {dbname}")
            except Exception as e:
                failed += 1
                print(f"  FAILED: {fname} -> {dbname}: {str(e)[:150]}")

    return deployed, failed


def test_patched_functions(patches):
    """Test patched functions with NULL arguments"""
    CALLABLE_ERRORS = {'23502', 'P0001', '22004', '2F005', '22P02', '23503', '23514', '42725'}
    success = 0
    callable_count = 0
    fail = 0

    for fname, patch in patches.items():
        db = patch['db']
        if not db:
            continue

        try:
            conn = psycopg2.connect(dbname=db, **DB_CONFIG)
            conn.autocommit = False
            cur = conn.cursor()

            # Get parameter count
            cur.execute("""
                SELECT count(*) FROM information_schema.parameters
                WHERE specific_schema = 'public'
                  AND specific_name LIKE %s || '%%'
                  AND parameter_mode IN ('IN', 'INOUT')
            """, (fname,))
            pcount = cur.fetchone()[0]

            null_args = ', '.join(['NULL'] * pcount)
            sql = f'SELECT {fname}({null_args})'
            cur.execute(sql)
            cur.fetchall()
            conn.rollback()
            success += 1
            callable_count += 1
            print(f"  OK: {fname}")
        except Exception as e:
            conn.rollback()
            code = e.pgcode if hasattr(e, 'pgcode') else 'unknown'
            if code in CALLABLE_ERRORS:
                callable_count += 1
                print(f"  CALLABLE (data issue): {fname} [{code}]")
            elif code == '42804' and 'structure of query' in str(e).lower():
                callable_count += 1
                print(f"  CALLABLE (SETOF): {fname}")
            else:
                fail += 1
                print(f"  FAIL: {fname} [{code}]: {str(e)[:100]}")
        finally:
            cur.close()
            conn.close()

    return success, callable_count, fail


if __name__ == '__main__':
    print("Loading patches...")
    patches = load_patches()
    print(f"Found {len(patches)} patches")

    if not patches:
        print("No patches found in procedures/patches/")
        print("Create .sql files with corrected function definitions.")
        print("Add '-- database: <dbname>' comment to specify target database.")
        sys.exit(0)

    if '--deploy' in sys.argv:
        print("\nDeploying patches...")
        deployed, failed = deploy_patches(patches)
        print(f"Deployed: {deployed}, Failed: {failed}")

        if '--test' in sys.argv:
            print("\nTesting patched functions...")
            ok, callable_c, fail = test_patched_functions(patches)
            print(f"Success: {ok}, Callable: {callable_c}, Fail: {fail}")
    else:
        print("\nApplying patches to SQL files...")
        applied = apply_patches_to_files(patches)
        print(f"Applied {applied} patches")
