#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SQL Server schema JSON -> PostgreSQL DDL generator.
Reads JSON schema files exported from SQL Server and produces
CREATE DATABASE / CREATE TABLE / CREATE INDEX / ALTER TABLE DDL
compatible with PostgreSQL.
"""

import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────

MIGRATION_DIR = Path(__file__).parent
DDL_DIR = MIGRATION_DIR / "ddl"

# Source JSON -> target PG database name mapping
DB_MAP = {
    "AionWorldLive_schema.json": "aion_world_live",
    "AionAccountDB_schema.json": "aion_account_db",
    "AionAccountCacheDB_schema.json": "aion_account_cache_db",
    "LIVE_AionGM_schema.json": "aion_gm",
}

# ── Data type mapping (SQL Server -> PostgreSQL) ──────────────────────────

TYPE_MAP = {
    "int": "integer",
    "bigint": "bigint",
    "smallint": "smallint",
    "tinyint": "smallint",
    "bit": "boolean",
    "float": "double precision",
    "real": "real",
    "money": "numeric(19,4)",
    "smallmoney": "numeric(10,4)",
    "text": "text",
    "ntext": "text",
    "datetime": "timestamp",
    "datetime2": "timestamp",
    "smalldatetime": "timestamp",
    "date": "date",
    "time": "time",
    "datetimeoffset": "timestamptz",
    "uniqueidentifier": "uuid",
    "image": "bytea",
    "xml": "xml",
    "sql_variant": "text",
    "timestamp": "bytea",
    "hierarchyid": "varchar(4000)",
    "geography": "text",
    "geometry": "text",
}


def map_type(col: dict) -> str:
    """Map a SQL Server column definition to a PostgreSQL type string."""
    dtype = col["DATA_TYPE"].lower()
    max_len = col.get("CHARACTER_MAXIMUM_LENGTH")
    precision = col.get("NUMERIC_PRECISION")
    scale = col.get("NUMERIC_SCALE")

    # Direct mappings (no parameters)
    if dtype in TYPE_MAP:
        return TYPE_MAP[dtype]

    # Character types with length
    if dtype in ("char", "nchar"):
        if max_len and max_len > 0:
            return f"char({max_len})"
        return "text"

    if dtype in ("varchar", "nvarchar"):
        if max_len is None or max_len == -1:
            return "text"
        if max_len > 0:
            return f"varchar({max_len})"
        return "text"

    # Decimal / numeric with precision and scale
    if dtype in ("decimal", "numeric"):
        if precision is not None and scale is not None:
            return f"numeric({precision},{scale})"
        if precision is not None:
            return f"numeric({precision})"
        return "numeric"

    # Binary types
    if dtype in ("binary", "varbinary"):
        return "bytea"

    # Fallback: return as-is (should not happen with complete mapping)
    return dtype


# ── Default value conversion ──────────────────────────────────────────────

def convert_default(raw: str, pg_type: str) -> str:
    """Convert a SQL Server column default expression to PostgreSQL syntax."""
    if raw is None:
        return None

    val = raw.strip()

    # Strip outer parentheses layers: ((0)) -> (0) -> 0
    while val.startswith("(") and val.endswith(")"):
        inner = val[1:-1]
        # Make sure it's balanced before stripping
        if inner.count("(") == inner.count(")"):
            val = inner
        else:
            break

    lower = val.lower()

    # Function conversions
    if lower == "getdate()":
        return "CURRENT_TIMESTAMP"
    if lower == "newid()":
        return "gen_random_uuid()"
    if lower in ("getutcdate()",):
        return "(CURRENT_TIMESTAMP AT TIME ZONE 'UTC')"

    # Empty string variants
    if val in ("N''", "''", "N\"\""):
        return "''"

    # Boolean conversions for bit columns
    if pg_type == "boolean":
        if val in ("0", "false"):
            return "false"
        if val in ("1", "true"):
            return "true"

    # Bytea columns: numeric defaults are not valid, convert to hex literal
    if pg_type == "bytea":
        if re.match(r"^-?\d+$", val):
            num = int(val)
            if num == 0:
                return "'\\x00'::bytea"
            hex_str = format(num, "x")
            if len(hex_str) % 2:
                hex_str = "0" + hex_str
            return f"'\\x{hex_str}'::bytea"

    # Timestamp columns: numeric 0 means epoch; date-like strings need casting
    if pg_type in ("timestamp", "timestamptz"):
        if val == "0":
            return "'1970-01-01 00:00:00'::timestamp"
        # SQL Server date string literal e.g. '1970/1/1 0:0:1'
        if re.match(r"^'\d{4}/", val):
            # Normalize slashes to dashes for PG
            normalized = val.replace("/", "-")
            return f"{normalized}::timestamp"

    # SQL Server dbo function references: drop them (cannot convert)
    if "[dbo]." in val or "dbo." in lower:
        return None

    # Numeric literal
    if re.match(r"^-?\d+(\.\d+)?$", val):
        return val

    # String literal: already has quotes
    if val.startswith("'") and val.endswith("'"):
        return val

    # N'...' style string literal
    if val.startswith("N'") and val.endswith("'"):
        return val[1:]  # strip leading N

    # Fallback: wrap in single quotes if it looks like text, otherwise return as-is
    return val


# ── SQL identifier helpers ────────────────────────────────────────────────

def quote_ident(name: str) -> str:
    """Quote a PostgreSQL identifier (lowercase) with double quotes if needed."""
    lower = name.lower()
    # Reserved words or names with special chars need quoting
    PG_RESERVED = {
        "user", "order", "group", "table", "select", "insert", "update",
        "delete", "index", "key", "primary", "foreign", "constraint",
        "check", "default", "column", "create", "drop", "alter", "add",
        "set", "type", "level", "name", "value", "time", "date", "limit",
        "offset", "end", "start", "position", "action", "zone", "role",
        "grant", "option", "comment", "character", "all", "rank",
        "window", "partition", "range", "row", "rows", "current",
        "session", "local", "global", "temp", "temporary", "function",
        "procedure", "trigger", "sequence", "view", "schema", "domain",
        "rule", "desc", "asc", "like", "in", "between", "case", "when",
        "then", "else", "cast", "is", "not", "null", "true", "false",
        "and", "or", "on", "as", "from", "where", "having", "with",
        "join", "left", "right", "inner", "outer", "cross", "full",
        "natural", "using", "union", "intersect", "except", "distinct",
        "references", "analyze", "do", "both", "leading", "trailing",
        "some", "any", "only", "initially", "freeze", "overlaps",
        "similar", "ilike", "placing", "collation", "concurrently",
        "lateral", "tablesample", "variadic", "verbose",
    }
    if lower in PG_RESERVED or not re.match(r"^[a-z_][a-z0-9_]*$", lower):
        return f'"{lower}"'
    return lower


# ── DDL generation ────────────────────────────────────────────────────────

def generate_ddl(schema: dict, pg_db_name: str) -> str:
    """Generate full DDL for one database."""
    lines = []
    tables = schema.get("tables", {})
    indexes_raw = schema.get("indexes", [])
    fks_raw = schema.get("foreign_keys", [])

    # ── Group indexes by (index_name, table_name) to handle same name across tables ──
    idx_groups = defaultdict(list)
    for idx in indexes_raw:
        key = (idx["index_name"], idx["table_name"])
        idx_groups[key].append(idx)

    # ── Separate primary-key indexes from non-PK indexes ──
    pk_map = {}  # table_name -> list of column names (ordered)
    non_pk_indexes = {}  # (index_name, table_name) -> list of index rows

    for (idx_name, table_name), rows in idx_groups.items():
        if rows[0].get("is_primary_key"):
            pk_map[table_name] = [r["column_name"] for r in rows]
        else:
            non_pk_indexes[(idx_name, table_name)] = rows

    # ── Group foreign keys by fk_name (handles composite FKs) ──
    fk_groups = defaultdict(list)
    for fk in fks_raw:
        fk_groups[fk["fk_name"]].append(fk)

    # ── Header ──
    lines.append(f"-- PostgreSQL DDL for database: {pg_db_name}")
    lines.append(f"-- Generated from SQL Server schema: {schema.get('database', 'unknown')}")
    lines.append(f"-- Tables: {len(tables)}")
    lines.append("")

    # ── CREATE TABLE statements ──
    table_count = 0
    index_count = 0
    fk_count = 0

    for table_name, table_data in tables.items():
        table_lower = table_name.lower()
        quoted_table = quote_ident(table_lower)
        columns = table_data.get("columns", [])

        lines.append(f"CREATE TABLE {quoted_table} (")

        col_defs = []
        for col in columns:
            col_name = quote_ident(col["COLUMN_NAME"].lower())
            pg_type = map_type(col)
            nullable = "NULL" if col.get("IS_NULLABLE") == "YES" else "NOT NULL"

            default_str = ""
            raw_default = col.get("COLUMN_DEFAULT")
            if raw_default is not None:
                converted = convert_default(raw_default, pg_type)
                if converted is not None:
                    default_str = f" DEFAULT {converted}"

            col_defs.append(f"    {col_name} {pg_type}{default_str} {nullable}".rstrip())

        # Add primary key constraint inline if available
        pk_cols = pk_map.get(table_name)
        if pk_cols:
            pk_col_list = ", ".join(quote_ident(c.lower()) for c in pk_cols)
            pk_name = quote_ident(f"pk_{table_lower}")
            col_defs.append(f"    CONSTRAINT {pk_name} PRIMARY KEY ({pk_col_list})")

        lines.append(",\n".join(col_defs))
        lines.append(");")
        lines.append("")
        table_count += 1

    # ── CREATE INDEX statements (non-primary-key) ──
    if non_pk_indexes:
        lines.append("-- ── Indexes ──────────────────────────────────────────")
        lines.append("")

    # Track used index names to avoid collisions when same index name spans multiple tables
    used_idx_names = set()

    for (idx_name, table_name), rows in non_pk_indexes.items():
        table_lower = table_name.lower()
        quoted_table = quote_ident(table_lower)
        is_unique = rows[0].get("is_unique", False)

        # Ensure unique index name in PG (append table name if collision)
        candidate = idx_name.lower()
        if candidate in used_idx_names:
            candidate = f"{candidate}_{table_lower}"
        used_idx_names.add(candidate)
        idx_name_pg = quote_ident(candidate)

        # Deduplicate columns while preserving order
        seen = set()
        unique_cols = []
        for r in rows:
            col_lower = r["column_name"].lower()
            if col_lower not in seen:
                seen.add(col_lower)
                unique_cols.append(col_lower)
        col_list = ", ".join(quote_ident(c) for c in unique_cols)

        unique_str = "UNIQUE " if is_unique else ""
        lines.append(f"CREATE {unique_str}INDEX {idx_name_pg} ON {quoted_table} ({col_list});")
        index_count += 1

    if non_pk_indexes:
        lines.append("")

    # ── FOREIGN KEY constraints ──
    if fk_groups:
        lines.append("-- ── Foreign Keys ─────────────────────────────────────")
        lines.append("")

    for fk_name, fk_rows in fk_groups.items():
        parent_table = fk_rows[0]["parent_table"]
        ref_table = fk_rows[0]["ref_table"]
        parent_cols = ", ".join(quote_ident(r["parent_column"].lower()) for r in fk_rows)
        ref_cols = ", ".join(quote_ident(r["ref_column"].lower()) for r in fk_rows)
        fk_name_lower = quote_ident(fk_name.lower())

        lines.append(
            f"ALTER TABLE {quote_ident(parent_table.lower())} "
            f"ADD CONSTRAINT {fk_name_lower} "
            f"FOREIGN KEY ({parent_cols}) REFERENCES {quote_ident(ref_table.lower())} ({ref_cols});"
        )
        fk_count += 1

    if fk_groups:
        lines.append("")

    return "\n".join(lines), table_count, index_count, fk_count


def main():
    """Main entry point: read all schema JSONs, generate DDL files."""
    DDL_DIR.mkdir(parents=True, exist_ok=True)

    results = {}

    for json_file, pg_db_name in DB_MAP.items():
        json_path = MIGRATION_DIR / json_file
        if not json_path.exists():
            print(f"[WARN] Schema file not found: {json_path}")
            continue

        with open(json_path, "r", encoding="utf-8") as f:
            schema = json.load(f)

        ddl_text, table_count, index_count, fk_count = generate_ddl(schema, pg_db_name)

        ddl_path = DDL_DIR / f"{pg_db_name}.sql"
        with open(ddl_path, "w", encoding="utf-8") as f:
            f.write(ddl_text)

        results[pg_db_name] = {
            "tables": table_count,
            "indexes": index_count,
            "foreign_keys": fk_count,
            "ddl_file": str(ddl_path),
        }
        print(f"[OK] {pg_db_name}: {table_count} tables, {index_count} indexes, {fk_count} FKs -> {ddl_path.name}")

    return results


if __name__ == "__main__":
    results = main()
    print("\nDDL generation complete.")
    for db, info in results.items():
        print(f"  {db}: {info['tables']} tables, {info['indexes']} indexes, {info['foreign_keys']} FKs")
