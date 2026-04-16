#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deploy PL/pgSQL stored procedures to PostgreSQL databases.
Reads SQL files, splits them into individual functions, and executes each one.
Records successes and failures with detailed error reporting.
"""

import json
import re
import sys
import os
from datetime import datetime

try:
    import psycopg2
except ImportError:
    print("Installing psycopg2-binary...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary", "-q"])
    import psycopg2


# Database connection config (env-overridable since 2026-04-11
# disaster recovery — local PG only by default).
PG_HOST     = os.environ.get("PG_HOST",     "127.0.0.1")
PG_PORT     = int(os.environ.get("PG_PORT", "5432"))
PG_USER     = os.environ.get("PG_USER",     "postgres")
PG_PASSWORD = os.environ.get("PG_PASSWORD", "postgres")

# Mapping: SQL file -> target database
DEPLOY_MAP = {
    "aion_world_live_procedures.sql": "aion_world_live",
    "aion_account_db_procedures.sql": "aion_account_db",
    "aion_account_cache_db_procedures.sql": "aion_account_cache_db",
    "aion_gm_procedures.sql": "aion_gm",
}

# Base directory for SQL files
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROCEDURES_DIR = os.path.join(BASE_DIR, "procedures")


def split_functions(sql_content):
    """
    Split a SQL file into individual CREATE OR REPLACE FUNCTION statements.
    Each function ends with '$$;' followed by optional whitespace/comments.
    Returns list of (function_name, sql_text) tuples.
    """
    # Split on the separator lines between functions
    # Pattern: find each CREATE OR REPLACE FUNCTION block
    pattern = re.compile(
        r'(CREATE\s+OR\s+REPLACE\s+FUNCTION\s+(\w+)\s*\(.*?\$\$;)',
        re.DOTALL | re.IGNORECASE
    )

    functions = []
    for match in pattern.finditer(sql_content):
        sql_text = match.group(1).strip()
        func_name = match.group(2).strip()
        functions.append((func_name, sql_text))

    return functions


def deploy_to_database(db_name, sql_file, all_errors):
    """
    Deploy all functions from sql_file to the specified database.
    Returns (success_count, fail_count, errors_list).
    """
    filepath = os.path.join(PROCEDURES_DIR, sql_file)

    if not os.path.exists(filepath):
        print(f"  [SKIP] File not found: {filepath}")
        return 0, 0, []

    # Read SQL file content
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Split into individual functions
    functions = split_functions(content)
    total = len(functions)
    print(f"  Found {total} functions in {sql_file}")

    if total == 0:
        return 0, 0, []

    # Connect to database
    try:
        conn = psycopg2.connect(
            host=PG_HOST,
            port=PG_PORT,
            user=PG_USER,
            password=PG_PASSWORD,
            dbname=db_name,
            connect_timeout=15,
            client_encoding='UTF8'
        )
        conn.autocommit = True
    except Exception as e:
        # Avoid calling str(e) directly as it can crash with Unicode errors
        err_msg = "Connection failed"
        try:
            # repr() is usually safer than str() for exceptions with encoding issues
            err_msg = repr(e)
            if "password authentication failed" in err_msg.lower():
                err_msg = "Password authentication failed"
            elif "timeout" in err_msg.lower():
                err_msg = "Connection timed out"
        except:
            pass
        
        print(f"  [ERROR] Cannot connect to {db_name}: {err_msg}")
        errors = [{"function": fn, "error": f"Connection failed: {err_msg}", "database": db_name} for fn, _ in functions]
        all_errors.extend(errors)
        return 0, total, errors

    success_count = 0
    fail_count = 0
    errors = []

    for func_name, sql_text in functions:
        try:
            cur = conn.cursor()
            cur.execute(sql_text)
            cur.close()
            success_count += 1
        except Exception as e:
            fail_count += 1
            try:
                error_msg = e.diag.message_primary if getattr(e, 'diag', None) else str(e)
            except:
                error_msg = "Unknown execution error (encoding issue)"
            # Truncate very long error messages
            if len(error_msg) > 500:
                error_msg = error_msg[:500] + "..."
            error_entry = {
                "function": func_name,
                "error": error_msg,
                "database": db_name
            }
            errors.append(error_entry)
            # Reset connection state after error
            try:
                if not conn.autocommit: conn.rollback()
            except:
                pass
            try:
                # Reconnect if connection is broken
                conn.close()
                conn = psycopg2.connect(
                    host=PG_HOST,
                    port=PG_PORT,
                    user=PG_USER,
                    password=PG_PASSWORD,
                    dbname=db_name,
                    connect_timeout=15,
                    client_encoding='UTF8'
                )
                conn.autocommit = True
            except:
                pass

    try:
        conn.close()
    except:
        pass

    all_errors.extend(errors)
    return success_count, fail_count, errors


def categorize_errors(errors):
    """
    Categorize errors by common error types for the summary report.
    """
    categories = {}
    for err in errors:
        msg = err["error"]
        # Extract the core PG error type
        if "syntax error" in msg.lower():
            cat = "Syntax error"
        elif "does not exist" in msg.lower() and "relation" in msg.lower():
            cat = "Missing table/relation"
        elif "does not exist" in msg.lower() and "function" in msg.lower():
            cat = "Missing function dependency"
        elif "does not exist" in msg.lower() and "column" in msg.lower():
            cat = "Missing column"
        elif "does not exist" in msg.lower() and "type" in msg.lower():
            cat = "Missing type"
        elif "does not exist" in msg.lower():
            cat = "Object does not exist"
        elif "already exists" in msg.lower():
            cat = "Object already exists"
        elif "permission denied" in msg.lower():
            cat = "Permission denied"
        elif "return" in msg.lower() and "type" in msg.lower():
            cat = "Return type mismatch"
        elif "convert" in msg.lower() or "cast" in msg.lower():
            cat = "Type conversion error"
        elif "connection" in msg.lower():
            cat = "Connection error"
        elif "nolock" in msg.lower():
            cat = "SQL Server syntax remnant (NOLOCK)"
        elif "sp_executesql" in msg.lower():
            cat = "SQL Server syntax remnant (sp_executesql)"
        else:
            cat = "Other"

        if cat not in categories:
            categories[cat] = 0
        categories[cat] += 1

    return categories


def main():
    """Main deployment entry point."""
    print("=" * 60)
    print("PL/pgSQL Stored Procedure Deployment")
    print(f"Target: {PG_HOST}:{PG_PORT}")
    print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    all_errors = []
    summary = {}

    for sql_file, db_name in DEPLOY_MAP.items():
        print(f"\n--- Deploying to [{db_name}] from {sql_file} ---")
        success, fail, errors = deploy_to_database(db_name, sql_file, all_errors)
        summary[db_name] = {
            "success": success,
            "fail": fail,
            "total": success + fail
        }
        print(f"  Result: {success} success, {fail} failed, {success + fail} total")

    # Save errors to JSON
    error_output_path = os.path.join(PROCEDURES_DIR, "deploy_errors.json")
    error_report = {
        "deploy_time": datetime.now().isoformat(),
        "target_host": f"{PG_HOST}:{PG_PORT}",
        "summary": summary,
        "error_categories": categorize_errors(all_errors),
        "total_errors": len(all_errors),
        "errors": all_errors
    }

    with open(error_output_path, "w", encoding="utf-8") as f:
        json.dump(error_report, f, indent=2, ensure_ascii=False)

    # Print final summary
    print("\n" + "=" * 60)
    print("DEPLOYMENT SUMMARY")
    print("=" * 60)

    total_success = 0
    total_fail = 0
    total_all = 0

    for db_name, stats in summary.items():
        total_success += stats["success"]
        total_fail += stats["fail"]
        total_all += stats["total"]
        status = "OK" if stats["fail"] == 0 else "PARTIAL"
        print(f"  [{status}] {db_name}: {stats['success']}/{stats['total']} deployed ({stats['fail']} failed)")

    print(f"\n  TOTAL: {total_success}/{total_all} deployed, {total_fail} failed")

    # Error categories
    if all_errors:
        categories = categorize_errors(all_errors)
        print(f"\n  Common error types ({len(categories)} categories):")
        for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
            print(f"    - {cat}: {count}")

    print(f"\n  Error details saved to: {error_output_path}")
    print(f"  End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
