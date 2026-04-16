#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Execute generated PostgreSQL DDL scripts on the target server.
Creates databases (DROP IF EXISTS first) and runs all DDL statements.
"""

import os
import sys
from pathlib import Path

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# ── Connection config ─────────────────────────────────────────────────────

PG_HOST = "123.56.80.174"
PG_PORT = 5432
PG_USER = "postgres"
PG_PASS = "postgres"

DDL_DIR = Path(__file__).parent / "ddl"

# Database names to create and their DDL files
DATABASES = [
    "aion_world_live",
    "aion_account_db",
    "aion_account_cache_db",
    "aion_gm",
]


def get_admin_conn():
    """Connect to the default 'postgres' database for admin operations."""
    conn = psycopg2.connect(
        host=PG_HOST, port=PG_PORT,
        user=PG_USER, password=PG_PASS,
        dbname="postgres",
    )
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    return conn


def create_database(db_name: str):
    """Drop and recreate a database."""
    conn = get_admin_conn()
    cur = conn.cursor()
    try:
        # Terminate existing connections to the target database
        cur.execute("""
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE datname = %s AND pid <> pg_backend_pid()
        """, (db_name,))

        cur.execute(f'DROP DATABASE IF EXISTS "{db_name}"')
        print(f"  [DROP] {db_name} dropped (if existed)")

        cur.execute(f'CREATE DATABASE "{db_name}" ENCODING \'UTF8\'')
        print(f"  [CREATE] {db_name} created")
    finally:
        cur.close()
        conn.close()


def execute_ddl(db_name: str, ddl_file: Path):
    """Connect to the target database and execute the DDL script."""
    with open(ddl_file, "r", encoding="utf-8") as f:
        ddl_sql = f.read()

    conn = psycopg2.connect(
        host=PG_HOST, port=PG_PORT,
        user=PG_USER, password=PG_PASS,
        dbname=db_name,
    )
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = conn.cursor()

    # Split by semicolons and execute statement by statement
    # (to get better error reporting)
    statements = []
    current = []
    for line in ddl_sql.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--") or not stripped:
            continue
        current.append(line)
        if stripped.endswith(";"):
            stmt = "\n".join(current).strip()
            if stmt:
                statements.append(stmt)
            current = []

    # Track counts
    tables_created = 0
    indexes_created = 0
    fks_created = 0
    errors = []

    for stmt in statements:
        try:
            cur.execute(stmt)
            upper = stmt.upper()
            if upper.startswith("CREATE TABLE"):
                tables_created += 1
            elif "CREATE INDEX" in upper or "CREATE UNIQUE INDEX" in upper:
                indexes_created += 1
            elif "FOREIGN KEY" in upper:
                fks_created += 1
        except Exception as e:
            error_msg = str(e).strip()
            # Extract first line of statement for context
            first_line = stmt.split("\n")[0][:80]
            errors.append(f"  [ERROR] {first_line}... => {error_msg}")
            # Continue execution despite errors

    cur.close()
    conn.close()

    return tables_created, indexes_created, fks_created, errors


def main():
    """Main entry: create databases and execute DDL."""
    print("=" * 60)
    print("PostgreSQL DDL Execution")
    print(f"Target: {PG_USER}@{PG_HOST}:{PG_PORT}")
    print("=" * 60)
    print()

    # Test connection first
    try:
        conn = get_admin_conn()
        conn.close()
        print("[OK] Connection to PostgreSQL successful\n")
    except Exception as e:
        print(f"[FATAL] Cannot connect to PostgreSQL: {e}")
        sys.exit(1)

    total_stats = {"tables": 0, "indexes": 0, "fks": 0, "errors": 0}

    for db_name in DATABASES:
        ddl_file = DDL_DIR / f"{db_name}.sql"
        if not ddl_file.exists():
            print(f"[WARN] DDL file not found: {ddl_file}")
            continue

        print(f"── {db_name} ──")

        # Step 1: Create database
        create_database(db_name)

        # Step 2: Execute DDL
        tables, indexes, fks, errors = execute_ddl(db_name, ddl_file)

        print(f"  [RESULT] {tables} tables, {indexes} indexes, {fks} foreign keys")
        if errors:
            print(f"  [WARN] {len(errors)} errors:")
            for err in errors[:10]:
                print(err)
            if len(errors) > 10:
                print(f"  ... and {len(errors) - 10} more errors")

        total_stats["tables"] += tables
        total_stats["indexes"] += indexes
        total_stats["fks"] += fks
        total_stats["errors"] += len(errors)
        print()

    print("=" * 60)
    print("Summary:")
    print(f"  Total tables:      {total_stats['tables']}")
    print(f"  Total indexes:     {total_stats['indexes']}")
    print(f"  Total foreign keys:{total_stats['fks']}")
    print(f"  Total errors:      {total_stats['errors']}")
    print("=" * 60)


if __name__ == "__main__":
    main()
