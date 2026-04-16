#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Data migration script: SQL Server -> PostgreSQL
Migrates all data from 4 SQL Server databases to corresponding PostgreSQL databases.
"""

import sys
import time
import traceback
from datetime import datetime

import pymssql
import psycopg2
import psycopg2.extras

# ============================================================
# Connection configurations
# ============================================================

SS_HOST = "123.56.80.174"
SS_PORT = 1433
SS_USER = "sa"
SS_PASS = "aion.5201314"

PG_HOST = "123.56.80.174"
PG_PORT = 5432
PG_USER = "postgres"
PG_PASS = "postgres"

# Database mapping: SQL Server DB -> PostgreSQL DB
DB_MAPPING = {
    "AionWorldLive": "aion_world_live",
    "AionAccountDB": "aion_account_db",
    "AionAccountCacheDB": "aion_account_cache_db",
    "LIVE_AionGM": "aion_gm",
}

BATCH_SIZE = 1000


def get_ss_connection(db_name):
    """Create SQL Server connection for the given database."""
    return pymssql.connect(
        server=SS_HOST,
        port=SS_PORT,
        user=SS_USER,
        password=SS_PASS,
        database=db_name,
        charset="utf8",
    )


def get_pg_connection(db_name):
    """Create PostgreSQL connection for the given database."""
    conn = psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        user=PG_USER,
        password=PG_PASS,
        database=db_name,
    )
    conn.autocommit = False
    return conn


def get_ss_tables_with_data(ss_conn):
    """Retrieve all user tables that contain data from SQL Server."""
    cursor = ss_conn.cursor()
    cursor.execute("""
        SELECT t.TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES t
        WHERE t.TABLE_TYPE = 'BASE TABLE'
          AND t.TABLE_SCHEMA = 'dbo'
        ORDER BY t.TABLE_NAME
    """)
    tables = [row[0] for row in cursor.fetchall()]
    cursor.close()

    # Filter tables that have data
    tables_with_data = []
    for table in tables:
        cursor = ss_conn.cursor()
        try:
            cursor.execute(f"SELECT TOP 1 1 FROM [{table}]")
            if cursor.fetchone():
                tables_with_data.append(table)
        except Exception:
            pass
        finally:
            cursor.close()
    return tables_with_data


def get_ss_columns(ss_conn, table_name):
    """Get column names for a SQL Server table."""
    cursor = ss_conn.cursor()
    cursor.execute(f"SELECT TOP 0 * FROM [{table_name}]")
    columns = [desc[0] for desc in cursor.description]
    cursor.close()
    return columns


def get_identity_columns(ss_conn, table_name):
    """Get identity column names for a SQL Server table."""
    cursor = ss_conn.cursor()
    cursor.execute("""
        SELECT c.name
        FROM sys.columns c
        JOIN sys.tables t ON c.object_id = t.object_id
        WHERE t.name = %s AND c.is_identity = 1
    """, (table_name,))
    result = [row[0] for row in cursor.fetchall()]
    cursor.close()
    return result


def get_bit_columns(ss_conn, table_name):
    """Get bit-type column indices for type conversion."""
    cursor = ss_conn.cursor()
    cursor.execute("""
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = %s AND TABLE_SCHEMA = 'dbo' AND DATA_TYPE = 'bit'
    """, (table_name,))
    result = [row[0] for row in cursor.fetchall()]
    cursor.close()
    return result


def convert_row(row, columns, bit_columns_set):
    """Convert a SQL Server row for PostgreSQL compatibility.

    Handles: bit->boolean, None passthrough, bytes passthrough, datetime passthrough.
    """
    converted = []
    for i, val in enumerate(row):
        col_name = columns[i]
        if val is None:
            converted.append(None)
        elif col_name in bit_columns_set:
            # SS bit -> PG boolean
            converted.append(bool(val))
        else:
            converted.append(val)
    return tuple(converted)


def reset_sequences(pg_conn, pg_table, pg_columns):
    """Reset serial/identity sequences after data migration."""
    cursor = pg_conn.cursor()
    for col in pg_columns:
        try:
            # Check if column has a sequence
            cursor.execute(
                "SELECT pg_get_serial_sequence(%s, %s)",
                (pg_table, col)
            )
            seq = cursor.fetchone()[0]
            if seq:
                cursor.execute(
                    f'SELECT setval(%s, COALESCE(MAX("{col}"), 1)) FROM "{pg_table}"',
                    (seq,)
                )
        except Exception:
            pg_conn.rollback()
            continue
    pg_conn.commit()
    cursor.close()


def check_pg_table_exists(pg_conn, table_name):
    """Check if a table exists in PostgreSQL."""
    cursor = pg_conn.cursor()
    cursor.execute("""
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = %s
        )
    """, (table_name,))
    exists = cursor.fetchone()[0]
    cursor.close()
    return exists


def migrate_table(ss_conn, pg_conn, ss_table, ss_db_name):
    """Migrate a single table from SQL Server to PostgreSQL.

    Returns (row_count, error_message). error_message is None on success.
    """
    pg_table = ss_table.lower()

    # Verify PG table exists
    if not check_pg_table_exists(pg_conn, pg_table):
        return 0, f"PG table '{pg_table}' does not exist, skipped"

    # Get column info
    ss_columns = get_ss_columns(ss_conn, ss_table)
    pg_columns = [c.lower() for c in ss_columns]
    bit_columns = get_bit_columns(ss_conn, ss_table)
    bit_columns_set = set(bit_columns)
    identity_columns = get_identity_columns(ss_conn, ss_table)

    # Build INSERT statement with OVERRIDING SYSTEM VALUE if identity columns exist
    col_list = ", ".join(f'"{c}"' for c in pg_columns)
    placeholders = ", ".join(["%s"] * len(pg_columns))

    overriding = ""
    if identity_columns:
        overriding = "OVERRIDING SYSTEM VALUE"

    insert_sql = f'INSERT INTO "{pg_table}" ({col_list}) {overriding} VALUES ({placeholders})'

    # Clear existing data in PG table before migration
    pg_cursor = pg_conn.cursor()
    pg_cursor.execute(f'DELETE FROM "{pg_table}"')
    pg_conn.commit()
    pg_cursor.close()

    # Read data from SQL Server
    ss_cursor = ss_conn.cursor()
    ss_cursor.execute(f"SELECT * FROM [{ss_table}]")

    total_rows = 0
    batch = []
    pg_cursor = pg_conn.cursor()

    while True:
        row = ss_cursor.fetchone()
        if row is None:
            break
        converted = convert_row(row, ss_columns, bit_columns_set)
        batch.append(converted)
        total_rows += 1

        if len(batch) >= BATCH_SIZE:
            psycopg2.extras.execute_batch(pg_cursor, insert_sql, batch, page_size=BATCH_SIZE)
            pg_conn.commit()
            batch = []

    # Insert remaining rows
    if batch:
        psycopg2.extras.execute_batch(pg_cursor, insert_sql, batch, page_size=BATCH_SIZE)
        pg_conn.commit()

    pg_cursor.close()
    ss_cursor.close()

    # Reset sequences for identity columns
    if identity_columns:
        reset_sequences(pg_conn, pg_table, [c.lower() for c in identity_columns])

    return total_rows, None


def verify_counts(ss_conn, pg_conn, ss_table):
    """Compare row counts between SS and PG for a given table."""
    pg_table = ss_table.lower()

    ss_cursor = ss_conn.cursor()
    ss_cursor.execute(f"SELECT COUNT(*) FROM [{ss_table}]")
    ss_count = ss_cursor.fetchone()[0]
    ss_cursor.close()

    pg_cursor = pg_conn.cursor()
    try:
        pg_cursor.execute(f'SELECT COUNT(*) FROM "{pg_table}"')
        pg_count = pg_cursor.fetchone()[0]
    except Exception:
        pg_count = -1
        pg_conn.rollback()
    pg_cursor.close()

    return ss_count, pg_count


def migrate_database(ss_db, pg_db):
    """Migrate all data from one SS database to corresponding PG database.

    Returns list of (table_name, row_count, status, detail) tuples.
    """
    print(f"\n{'='*70}")
    print(f"  Migrating: {ss_db} -> {pg_db}")
    print(f"{'='*70}")

    results = []

    try:
        ss_conn = get_ss_connection(ss_db)
        pg_conn = get_pg_connection(pg_db)
    except Exception as e:
        print(f"  [ERROR] Connection failed: {e}")
        return [("*CONNECTION*", 0, "FAIL", str(e))]

    try:
        tables = get_ss_tables_with_data(ss_conn)
        print(f"  Found {len(tables)} tables with data")

        for idx, table in enumerate(tables, 1):
            prefix = f"  [{idx}/{len(tables)}] {table}"
            try:
                start = time.time()
                rows, err = migrate_table(ss_conn, pg_conn, table, ss_db)
                elapsed = time.time() - start

                if err:
                    print(f"{prefix}: SKIP - {err}")
                    results.append((table, 0, "SKIP", err))
                else:
                    # Verify
                    ss_count, pg_count = verify_counts(ss_conn, pg_conn, table)
                    match = "OK" if ss_count == pg_count else f"MISMATCH(SS={ss_count},PG={pg_count})"
                    print(f"{prefix}: {rows} rows in {elapsed:.1f}s [{match}]")
                    results.append((table, rows, match, None))

            except Exception as e:
                pg_conn.rollback()
                err_msg = str(e).split('\n')[0][:120]
                print(f"{prefix}: FAIL - {err_msg}")
                results.append((table, 0, "FAIL", err_msg))

    finally:
        ss_conn.close()
        pg_conn.close()

    return results


def main():
    """Main entry point for the migration."""
    print(f"Migration started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"SQL Server: {SS_HOST}:{SS_PORT}")
    print(f"PostgreSQL: {PG_HOST}:{PG_PORT}")

    all_results = {}
    overall_start = time.time()

    for ss_db, pg_db in DB_MAPPING.items():
        db_start = time.time()
        results = migrate_database(ss_db, pg_db)
        db_elapsed = time.time() - db_start
        all_results[ss_db] = (results, db_elapsed)

    # Print summary
    total_elapsed = time.time() - overall_start
    print(f"\n\n{'='*70}")
    print(f"  MIGRATION SUMMARY")
    print(f"  Total time: {total_elapsed:.1f}s")
    print(f"{'='*70}")

    grand_total_rows = 0
    grand_ok = 0
    grand_fail = 0
    grand_skip = 0

    for ss_db, (results, elapsed) in all_results.items():
        pg_db = DB_MAPPING[ss_db]
        ok = sum(1 for r in results if r[2] == "OK")
        fail = sum(1 for r in results if r[2] == "FAIL")
        skip = sum(1 for r in results if r[2] == "SKIP")
        mismatch = sum(1 for r in results if "MISMATCH" in r[2])
        total_rows = sum(r[1] for r in results)

        grand_total_rows += total_rows
        grand_ok += ok
        grand_fail += fail
        grand_skip += skip

        print(f"\n  {ss_db} -> {pg_db} ({elapsed:.1f}s)")
        print(f"  {'Table':<40} {'Rows':>8} {'Status':<20}")
        print(f"  {'-'*40} {'-'*8} {'-'*20}")
        for table, rows, status, detail in results:
            detail_str = f" ({detail})" if detail else ""
            print(f"  {table:<40} {rows:>8} {status:<20}{detail_str}")
        print(f"  {'':->68}")
        print(f"  Subtotal: {total_rows} rows | OK:{ok} FAIL:{fail} SKIP:{skip} MISMATCH:{mismatch}")

    print(f"\n  {'='*68}")
    print(f"  Grand Total: {grand_total_rows} rows | OK:{grand_ok} FAIL:{grand_fail} SKIP:{grand_skip}")
    print(f"  Finished at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*70}")

    # Return exit code based on failures
    if grand_fail > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
