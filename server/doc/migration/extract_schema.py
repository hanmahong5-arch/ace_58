"""
Extract complete schema information from SQL Server databases for PostgreSQL migration.
Connects to each database, queries metadata, and saves as structured JSON.
"""

import json
import sys
import os
import traceback

try:
    import pymssql
except ImportError:
    print("pymssql not installed, attempting install...")
    os.system("pip install pymssql")
    import pymssql

# Connection settings
HOST = "123.56.80.174"
PORT = 1433
USER = "sa"
PASSWORD = "aion.5201314"

DATABASES = ["AionWorldLive", "AionAccountDB", "AionAccountCacheDB", "LIVE_AionGM"]

OUTPUT_DIR = "D:/拾光ai/doc/migration"


def extract_schema(db_name):
    """Extract full schema from a single database and return as dict."""
    print(f"\n{'='*60}")
    print(f"Extracting schema from: {db_name}")
    print(f"{'='*60}")

    result = {
        "database": db_name,
        "tables": {},
        "indexes": [],
        "foreign_keys": [],
        "procedures": {}
    }

    try:
        conn = pymssql.connect(
            server=HOST,
            port=PORT,
            user=USER,
            password=PASSWORD,
            database=db_name,
            charset="utf8",
            login_timeout=15,
            timeout=60
        )
        cursor = conn.cursor(as_dict=True)
        print(f"  Connected to {db_name}")

        # 1. Table columns
        print("  Querying table columns...")
        cursor.execute("""
            SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH,
                   NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE, COLUMN_DEFAULT
            FROM INFORMATION_SCHEMA.COLUMNS
            ORDER BY TABLE_NAME, ORDINAL_POSITION
        """)
        for row in cursor:
            tname = row["TABLE_NAME"]
            if tname not in result["tables"]:
                result["tables"][tname] = {"columns": [], "row_count": 0}
            # Convert non-serializable types
            col = {}
            for k, v in row.items():
                if k == "TABLE_NAME":
                    continue
                if isinstance(v, (int, float, str, bool, type(None))):
                    col[k] = v
                else:
                    col[k] = str(v)
            result["tables"][tname]["columns"].append(col)
        print(f"    Found {len(result['tables'])} tables")

        # 2. Indexes and primary keys
        print("  Querying indexes...")
        cursor.execute("""
            SELECT i.name as index_name, t.name as table_name,
                   c.name as column_name, i.is_primary_key, i.is_unique
            FROM sys.indexes i
            JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            JOIN sys.tables t ON i.object_id = t.object_id
            WHERE i.name IS NOT NULL
            ORDER BY t.name, i.name
        """)
        for row in cursor:
            idx = {}
            for k, v in row.items():
                if isinstance(v, (int, float, str, bool, type(None))):
                    idx[k] = v
                else:
                    idx[k] = str(v)
            result["indexes"].append(idx)
        print(f"    Found {len(result['indexes'])} index entries")

        # 3. Foreign keys
        print("  Querying foreign keys...")
        cursor.execute("""
            SELECT fk.name as fk_name, tp.name as parent_table, cp.name as parent_column,
                   tr.name as ref_table, cr.name as ref_column
            FROM sys.foreign_keys fk
            JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
            JOIN sys.tables tp ON fkc.parent_object_id = tp.object_id
            JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
            JOIN sys.tables tr ON fkc.referenced_object_id = tr.object_id
            JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
        """)
        for row in cursor:
            fk = {}
            for k, v in row.items():
                if isinstance(v, (int, float, str, bool, type(None))):
                    fk[k] = v
                else:
                    fk[k] = str(v)
            result["foreign_keys"].append(fk)
        print(f"    Found {len(result['foreign_keys'])} foreign key entries")

        # 4. Stored procedures
        print("  Querying stored procedures...")
        cursor.execute("""
            SELECT p.name as proc_name, m.definition
            FROM sys.procedures p
            JOIN sys.sql_modules m ON p.object_id = m.object_id
        """)
        for row in cursor:
            proc_name = row["proc_name"]
            definition = row["definition"]
            if definition is not None:
                result["procedures"][proc_name] = definition
            else:
                result["procedures"][proc_name] = ""
        print(f"    Found {len(result['procedures'])} stored procedures")

        # 5. Row counts per table
        print("  Querying row counts...")
        cursor.execute("""
            SELECT t.name as table_name, SUM(p.rows) as row_count
            FROM sys.tables t
            JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
            GROUP BY t.name
        """)
        for row in cursor:
            tname = row["table_name"]
            rcount = row["row_count"]
            if tname in result["tables"]:
                result["tables"][tname]["row_count"] = int(rcount) if rcount else 0
            else:
                # Table exists but had no columns in INFORMATION_SCHEMA (unlikely)
                result["tables"][tname] = {"columns": [], "row_count": int(rcount) if rcount else 0}
        print(f"    Row counts updated")

        conn.close()
        print(f"  Done with {db_name}")

    except Exception as e:
        print(f"  ERROR extracting {db_name}: {e}")
        traceback.print_exc()
        result["error"] = str(e)

    return result


def main():
    """Extract schemas from all databases and save to JSON files."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Test connectivity first
    print("Testing SQL Server connectivity...")
    try:
        test_conn = pymssql.connect(
            server=HOST, port=PORT, user=USER, password=PASSWORD,
            login_timeout=15
        )
        test_conn.close()
        print("Connection successful!")
    except Exception as e:
        print(f"Connection failed: {e}")
        traceback.print_exc()
        sys.exit(1)

    summary = {}

    for db_name in DATABASES:
        schema = extract_schema(db_name)

        # Save to JSON
        outpath = os.path.join(OUTPUT_DIR, f"{db_name}_schema.json")
        with open(outpath, "w", encoding="utf-8") as f:
            json.dump(schema, f, ensure_ascii=False, indent=2, default=str)
        print(f"  Saved: {outpath}")

        # Collect summary
        table_count = len(schema.get("tables", {}))
        total_rows = sum(t.get("row_count", 0) for t in schema.get("tables", {}).values())
        proc_count = len(schema.get("procedures", {}))
        idx_count = len(schema.get("indexes", []))
        fk_count = len(schema.get("foreign_keys", []))
        summary[db_name] = {
            "tables": table_count,
            "total_rows": total_rows,
            "indexes": idx_count,
            "foreign_keys": fk_count,
            "procedures": proc_count,
            "has_error": "error" in schema
        }

    # Print summary
    print(f"\n{'='*60}")
    print("EXTRACTION SUMMARY")
    print(f"{'='*60}")
    for db, info in summary.items():
        status = "ERROR" if info["has_error"] else "OK"
        print(f"  {db}: [{status}] {info['tables']} tables, "
              f"{info['total_rows']} rows, {info['indexes']} idx, "
              f"{info['foreign_keys']} FK, {info['procedures']} procs")


if __name__ == "__main__":
    main()
