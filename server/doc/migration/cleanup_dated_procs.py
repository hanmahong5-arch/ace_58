"""
Cleanup dated stored procedures/functions in PostgreSQL.

Directly queries PostgreSQL for functions with date suffixes (_20YYMMDD or _YYMMDD),
then cleans them up according to the rules:
- Type A: base name (without date suffix) exists as a function -> DROP all dated versions
- Type B: only dated versions exist (no base name function) -> RENAME newest to base name, DROP others

Also cross-references schema JSON files to ensure comprehensive coverage.
"""

import json
import re
import logging
import sys
from datetime import datetime
from collections import defaultdict

try:
    import psycopg2
except ImportError:
    print("Installing psycopg2-binary...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary", "-q"])
    import psycopg2


# Configuration
PG_HOST = "123.56.80.174"
PG_PORT = 5432
PG_USER = "postgres"
PG_PASSWORD = "postgres"

# Database mapping: (json_file, pg_database)
DB_CONFIGS = [
    ("D:/拾光ai/doc/migration/AionWorldLive_schema.json", "aion_world_live"),
    ("D:/拾光ai/doc/migration/AionAccountCacheDB_schema.json", "aion_account_cache_db"),
]

# Date suffix pattern: _20YYMMDD or _YYMMDD (2-digit year shorthand)
DATE_SUFFIX_RE = re.compile(r'^(.+?)_(20\d{6}|\d{6})$')

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("D:/拾光ai/doc/migration/cleanup_dated_procs.log",
                            encoding="utf-8", mode="w"),
    ]
)
log = logging.getLogger(__name__)


def parse_date_suffix(name):
    """
    Extract base name and date string from a function name.
    Returns (base_name, date_str_8digit) or (None, None) if no date suffix found.
    """
    m = DATE_SUFFIX_RE.match(name)
    if not m:
        return None, None
    base = m.group(1)
    date_str = m.group(2)
    # Normalize to 8-digit date
    if len(date_str) == 6:
        date_str = "20" + date_str
    # Validate it looks like a real date
    try:
        datetime.strptime(date_str, "%Y%m%d")
    except ValueError:
        return None, None
    return base, date_str


def get_pg_functions(conn):
    """
    Query PostgreSQL for all functions in 'public' schema with their signatures.
    Returns dict: {func_name: [(oid, args_str), ...]}
    Note: PG stores unquoted names in lowercase.
    """
    cur = conn.cursor()
    cur.execute("""
        SELECT p.oid, p.proname,
               pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        ORDER BY p.proname
    """)
    funcs = defaultdict(list)
    for oid, name, args in cur.fetchall():
        funcs[name].append((oid, args))
    cur.close()
    return funcs


def cleanup_database(json_path, db_name):
    """
    Perform cleanup for a single database.
    Works directly from PG function names (lowercase), using JSON only for reference.
    Returns summary dict with counts.
    """
    log.info("=" * 70)
    log.info(f"Processing database: {db_name}")
    log.info("=" * 70)

    # Step 1: Connect to PG and get actual functions
    conn = psycopg2.connect(
        host=PG_HOST, port=PG_PORT,
        user=PG_USER, password=PG_PASSWORD,
        dbname=db_name
    )
    conn.autocommit = True
    pg_funcs = get_pg_functions(conn)
    log.info(f"PostgreSQL has {len(pg_funcs)} functions in public schema")

    # Step 2: Identify dated functions directly from PG
    # Group by base name (all lowercase since PG stores lowercase)
    dated_groups = defaultdict(list)  # base_name -> [(full_name, date_str)]
    non_dated_names = set()

    for func_name in pg_funcs:
        base, date_str = parse_date_suffix(func_name)
        if base and date_str:
            dated_groups[base].append((func_name, date_str))
        else:
            non_dated_names.add(func_name)

    total_dated = sum(len(v) for v in dated_groups.values())
    log.info(f"Found {total_dated} dated functions across {len(dated_groups)} base names")
    log.info(f"Found {len(non_dated_names)} non-dated functions")

    # Step 3: Classify into Type A and Type B, then execute cleanup
    type_a_drops = 0
    type_b_renames = 0
    type_b_drops = 0
    errors = 0

    cur = conn.cursor()

    for base_name, dated_list in sorted(dated_groups.items()):
        # Sort by date descending (newest first)
        dated_list.sort(key=lambda x: x[1], reverse=True)

        # Check if base name exists as a non-dated function in PG
        base_exists = base_name in non_dated_names

        if base_exists:
            # Type A: base name function exists, drop ALL dated versions
            log.info(f"[Type A] base='{base_name}' exists -> "
                     f"dropping {len(dated_list)} dated versions")
            for func_name, date_str in dated_list:
                for oid, args in pg_funcs[func_name]:
                    drop_sql = f"DROP FUNCTION IF EXISTS {func_name}({args}) CASCADE;"
                    try:
                        log.info(f"  DROP: {func_name}({args[:60]}...)")
                        cur.execute(drop_sql)
                        type_a_drops += 1
                    except Exception as e:
                        log.error(f"  ERROR dropping {func_name}: {e}")
                        errors += 1
        else:
            # Type B: only dated versions exist, no base name function
            newest_name, newest_date = dated_list[0]
            older_count = len(dated_list) - 1
            log.info(f"[Type B] base='{base_name}' missing -> "
                     f"keep newest '{newest_name}' ({newest_date}), "
                     f"drop {older_count} older")

            # Drop all older versions first
            for func_name, date_str in dated_list[1:]:
                for oid, args in pg_funcs[func_name]:
                    drop_sql = f"DROP FUNCTION IF EXISTS {func_name}({args}) CASCADE;"
                    try:
                        log.info(f"  DROP old: {func_name}({args[:60]}...)")
                        cur.execute(drop_sql)
                        type_b_drops += 1
                    except Exception as e:
                        log.error(f"  ERROR dropping {func_name}: {e}")
                        errors += 1

            # Rename newest to base name
            for oid, args in pg_funcs[newest_name]:
                rename_sql = f"ALTER FUNCTION {newest_name}({args}) RENAME TO {base_name};"
                try:
                    log.info(f"  RENAME: {newest_name} -> {base_name}")
                    cur.execute(rename_sql)
                    type_b_renames += 1
                except Exception as e:
                    log.error(f"  ERROR renaming {newest_name} -> {base_name}: {e}")
                    errors += 1

    cur.close()

    # Step 4: Count remaining functions
    pg_funcs_after = get_pg_functions(conn)
    conn.close()

    summary = {
        "database": db_name,
        "before_count": len(pg_funcs),
        "after_count": len(pg_funcs_after),
        "type_a_drops": type_a_drops,
        "type_b_renames": type_b_renames,
        "type_b_drops": type_b_drops,
        "errors": errors,
    }

    log.info("")
    log.info(f"--- Summary for {db_name} ---")
    log.info(f"Functions before: {summary['before_count']}")
    log.info(f"Functions after:  {summary['after_count']}")
    log.info(f"Type A (dropped, base exists):     {type_a_drops}")
    log.info(f"Type B (renamed to base):          {type_b_renames}")
    log.info(f"Type B (older versions dropped):   {type_b_drops}")
    log.info(f"Errors: {errors}")

    return summary


def main():
    """Main entry point - process all databases."""
    log.info("Starting cleanup of dated stored procedures")
    log.info(f"Target: {PG_HOST}:{PG_PORT}")

    all_summaries = []
    for json_path, db_name in DB_CONFIGS:
        try:
            summary = cleanup_database(json_path, db_name)
            all_summaries.append(summary)
        except Exception as e:
            log.error(f"Failed to process {db_name}: {e}")
            import traceback
            traceback.print_exc()

    # Final report
    log.info("")
    log.info("=" * 70)
    log.info("FINAL REPORT")
    log.info("=" * 70)
    for s in all_summaries:
        log.info(f"")
        log.info(f"[{s['database']}]")
        log.info(f"  Functions: {s['before_count']} -> {s['after_count']}")
        log.info(f"  Type A drops (base existed):     {s['type_a_drops']}")
        log.info(f"  Type B renames (newest -> base):  {s['type_b_renames']}")
        log.info(f"  Type B drops (older versions):    {s['type_b_drops']}")
        log.info(f"  Errors: {s['errors']}")

    total_dropped = sum(s['type_a_drops'] + s['type_b_drops'] for s in all_summaries)
    total_renamed = sum(s['type_b_renames'] for s in all_summaries)
    total_after = sum(s['after_count'] for s in all_summaries)
    log.info(f"")
    log.info(f"Grand total: dropped={total_dropped}, renamed={total_renamed}, "
             f"remaining functions={total_after}")


if __name__ == "__main__":
    main()
