#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Sync Migration Output to AionCore
===================================
Replaces AionCore's broken sql/pg_functions/ with our properly converted
PL/pgSQL functions from doc/migration/procedures/.

Steps:
1. Back up existing aioncore/sql/pg_functions/ → pg_functions_backup/
2. Split our 4 combined SQL files into individual function files
3. Apply 73 manual patches from procedures/patches/
4. Write to aioncore/sql/pg_functions/ with correct naming convention
5. Generate a manifest with function → database mapping

Naming convention (matching AionCore's existing pattern):
  WorldLive functions:     aion_xxx.sql, gm_xxx.sql, sp_xxx.sql (no prefix)
  AccountDB functions:     AccountDB_xxx.sql
  AccountCacheDB functions: CacheDB_xxx.sql
  GM functions:            GM_xxx.sql (only for LIVE_AionGM DB functions)
"""

import re
import os
import sys
import json
import shutil
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
AIONCORE_ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, '..', '..', 'aioncore'))
PG_FUNCS_DIR = os.path.join(AIONCORE_ROOT, 'sql', 'pg_functions')
BACKUP_DIR = os.path.join(AIONCORE_ROOT, 'sql', 'pg_functions_backup')
PROC_DIR = os.path.join(SCRIPT_DIR, 'procedures')
PATCH_DIR = os.path.join(PROC_DIR, 'patches')

# Map database names to SQL files and file naming prefixes
DB_MAP = {
    'aion_world_live': {
        'sql_file': 'aion_world_live_procedures.sql',
        'prefix': '',  # No prefix for WorldLive (matches existing convention)
    },
    'aion_account_db': {
        'sql_file': 'aion_account_db_procedures.sql',
        'prefix': 'AccountDB_',
    },
    'aion_account_cache_db': {
        'sql_file': 'aion_account_cache_db_procedures.sql',
        'prefix': 'CacheDB_',
    },
    'aion_gm': {
        'sql_file': 'aion_gm_procedures.sql',
        'prefix': 'GM_',
    },
}


def split_sql_file(filepath):
    """Split a combined SQL file into individual function definitions"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Match individual CREATE OR REPLACE FUNCTION blocks
    functions = {}
    for m in re.finditer(
        r'(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+(\w+)\s*\(.*?\$\$;)',
        content, re.DOTALL
    ):
        func_sql = m.group(1)
        func_name = m.group(2)
        functions[func_name] = func_sql

    return functions


def load_patches():
    """Load manual patches from patches/ directory"""
    patches = {}
    if not os.path.exists(PATCH_DIR):
        return patches

    for patch_file in os.listdir(PATCH_DIR):
        if not patch_file.endswith('.sql'):
            continue
        filepath = os.path.join(PATCH_DIR, patch_file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Extract function name and database
        db_match = re.search(r'--\s*database:\s*(\w+)', content)
        func_match = re.search(r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+(\w+)\s*\(', content, re.IGNORECASE)

        if func_match:
            fname = func_match.group(1).lower()
            db = db_match.group(1) if db_match else None
            # Remove the database comment for clean output
            clean_content = re.sub(r'--\s*database:\s*\w+\s*\n?', '', content).strip()
            patches[fname] = {'db': db, 'sql': clean_content}

    return patches


def get_original_case_name(func_name_lower, original_names):
    """Find original case name from the existing file list"""
    for name in original_names:
        if name.lower() == func_name_lower.lower():
            return name
    return func_name_lower


def main():
    print("=" * 60)
    print("Sync Migration Output → AionCore")
    print("=" * 60)
    print()

    # Step 1: Back up existing pg_functions
    if os.path.exists(PG_FUNCS_DIR):
        existing_count = len([f for f in os.listdir(PG_FUNCS_DIR) if f.endswith('.sql')])
        print(f"1. Backing up {existing_count} existing files...")

        # Collect original file names for case preservation
        original_names = {}
        for f in os.listdir(PG_FUNCS_DIR):
            if f.endswith('.sql'):
                # Extract function name from filename (remove prefix and .sql)
                base = f[:-4]  # Remove .sql
                for prefix in ['AccountDB_', 'CacheDB_', 'GM_']:
                    if base.startswith(prefix):
                        base = base[len(prefix):]
                        break
                original_names[base.lower()] = base

        if os.path.exists(BACKUP_DIR):
            shutil.rmtree(BACKUP_DIR)
        shutil.copytree(PG_FUNCS_DIR, BACKUP_DIR)
        print(f"   Backed up to: {BACKUP_DIR}")

        # Clear the directory
        for f in os.listdir(PG_FUNCS_DIR):
            if f.endswith('.sql'):
                os.remove(os.path.join(PG_FUNCS_DIR, f))
    else:
        os.makedirs(PG_FUNCS_DIR, exist_ok=True)
        original_names = {}
        print("1. No existing pg_functions/ directory, creating fresh.")

    # Step 2: Load patches
    patches = load_patches()
    print(f"2. Loaded {len(patches)} manual patches")

    # Step 3: Split and write functions
    manifest = {}
    total_written = 0
    patched_count = 0

    for db_name, db_config in DB_MAP.items():
        sql_path = os.path.join(PROC_DIR, db_config['sql_file'])
        if not os.path.exists(sql_path):
            print(f"   WARNING: {sql_path} not found, skipping")
            continue

        functions = split_sql_file(sql_path)
        prefix = db_config['prefix']

        print(f"3. Processing {db_name}: {len(functions)} functions (prefix: '{prefix}')")

        for func_name, func_sql in functions.items():
            # Apply patch if available
            if func_name.lower() in patches:
                patch = patches[func_name.lower()]
                if patch['db'] is None or patch['db'] == db_name:
                    func_sql = patch['sql']
                    patched_count += 1

            # Determine filename: preserve original case if possible
            display_name = get_original_case_name(func_name, original_names)
            filename = f"{prefix}{display_name}.sql"
            filepath = os.path.join(PG_FUNCS_DIR, filename)

            # Write with header comment
            header = f"-- Database: {db_name}\n"
            header += f"-- Function: {func_name}\n"
            header += f"-- Synced from doc/migration/ on {datetime.now().strftime('%Y-%m-%d')}\n\n"

            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(header + func_sql + '\n')

            manifest[func_name] = {
                'database': db_name,
                'file': filename,
                'patched': func_name.lower() in patches,
            }
            total_written += 1

    # Step 4: Write manifest
    manifest_path = os.path.join(PG_FUNCS_DIR, '_manifest.json')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump({
            'generated': datetime.now().isoformat(),
            'source': 'doc/migration/procedures/',
            'total_functions': total_written,
            'manual_patches_applied': patched_count,
            'databases': {db: len([v for v in manifest.values() if v['database'] == db])
                          for db in DB_MAP},
            'functions': manifest
        }, f, indent=2, ensure_ascii=False)

    print()
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"  Total functions written: {total_written}")
    print(f"  Manual patches applied:  {patched_count}")
    for db_name in DB_MAP:
        count = len([v for v in manifest.values() if v['database'] == db_name])
        print(f"  {db_name}: {count}")
    print(f"  Manifest: {manifest_path}")
    print(f"  Backup:   {BACKUP_DIR}")

    return total_written


if __name__ == '__main__':
    total = main()
    print(f"\nDone. {total} functions synced to AionCore.")
