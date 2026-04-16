#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
T-SQL Stored Procedure to PL/pgSQL Function Converter
=====================================================
Reads SQL Server schema JSON files and converts stored procedures
to PostgreSQL PL/pgSQL functions. Uses statement-level parsing
to correctly handle multi-line SQL statements.

Usage:
    python convert_procedures.py

Output:
    procedures/aion_world_live_procedures.sql
    procedures/aion_account_db_procedures.sql
    procedures/aion_account_cache_db_procedures.sql
    procedures/aion_gm_procedures.sql
"""

import json
import re
import os
import sys
import time
from dataclasses import dataclass, field
from typing import List, Tuple, Optional
from enum import Enum

# --- Constants ---

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "procedures")

# Input files mapped to output filenames
SOURCE_FILES = {
    "AionWorldLive_schema.json": "aion_world_live_procedures.sql",
    "AionAccountDB_schema.json": "aion_account_db_procedures.sql",
    "AionAccountCacheDB_schema.json": "aion_account_cache_db_procedures.sql",
    "LIVE_AionGM_schema.json": "aion_gm_procedures.sql",
}

# T-SQL to PG data type mapping
TYPE_MAP = {
    "int": "integer",
    "bigint": "bigint",
    "smallint": "smallint",
    "tinyint": "smallint",
    "bit": "boolean",
    "float": "double precision",
    "real": "real",
    "decimal": "numeric",
    "numeric": "numeric",
    "money": "numeric(19,4)",
    "smallmoney": "numeric(10,4)",
    "datetime": "timestamp",
    "datetime2": "timestamp",
    "smalldatetime": "timestamp",
    "date": "date",
    "time": "time",
    "datetimeoffset": "timestamptz",
    "char": "char",
    "varchar": "varchar",
    "nchar": "char",
    "nvarchar": "varchar",
    "text": "text",
    "ntext": "text",
    "binary": "bytea",
    "varbinary": "bytea",
    "image": "bytea",
    "uniqueidentifier": "uuid",
    "xml": "xml",
    "sql_variant": "text",
    "sysname": "varchar(128)",
    "timestamp": "bytea",  # SQL Server timestamp is rowversion
}


class Confidence(Enum):
    """Conversion confidence levels"""
    AUTO = "auto"
    REVIEW = "review"
    MANUAL = "manual"


@dataclass
class ConversionResult:
    """Result of converting one stored procedure"""
    name: str
    confidence: Confidence
    sql: str
    warnings: List[str] = field(default_factory=list)
    original_sql: str = ""


@dataclass
class ProcParam:
    """Represents a stored procedure parameter"""
    name: str           # Original name with @
    pg_name: str        # PostgreSQL name (p_xxx)
    data_type: str      # PostgreSQL data type
    is_output: bool     # OUTPUT parameter
    default_value: Optional[str]


def max_confidence(current: Confidence, new: Confidence) -> Confidence:
    """Return the lower confidence level"""
    order = {Confidence.AUTO: 0, Confidence.REVIEW: 1, Confidence.MANUAL: 2}
    return current if order[current] >= order[new] else new


# --- Type Conversion ---

def convert_type(tsql_type: str) -> str:
    """Convert a T-SQL data type declaration to PostgreSQL equivalent"""
    tsql_type = tsql_type.strip()
    match = re.match(r"(\w+)\s*\(\s*(max|\d+(?:\s*,\s*\d+)?)\s*\)", tsql_type, re.IGNORECASE)
    if match:
        base = match.group(1).lower()
        args = match.group(2).lower()
        pg_base = TYPE_MAP.get(base, base)
        if args == "max":
            if base in ("varchar", "nvarchar", "char", "nchar"):
                return "text"
            elif base in ("varbinary", "binary"):
                return "bytea"
            return pg_base
        if base in ("binary", "varbinary", "image"):
            return "bytea"
        if base == "timestamp":
            return "bytea"
        return f"{pg_base}({args})"
    else:
        base = tsql_type.lower().strip()
        return TYPE_MAP.get(base, base)


# --- Parameter Parsing ---

def parse_parameters(param_block: str) -> List[ProcParam]:
    """Parse T-SQL parameter declarations into structured list"""
    params = []
    if not param_block or not param_block.strip():
        return params

    # Remove inline comments (-- style)
    param_block = re.sub(r'--[^\n]*', '', param_block)
    # Remove block comments
    param_block = re.sub(r'/\*.*?\*/', '', param_block, flags=re.DOTALL)
    # Normalize whitespace
    param_block = re.sub(r'\s+', ' ', param_block.strip())

    # Split on commas that are followed by @
    parts = re.split(r',\s*(?=@)', param_block)

    for part in parts:
        part = part.strip()
        if not part:
            continue

        # Pattern: @name [AS] type [(size)] [= default] [OUTPUT|OUT]
        # Support optional AS keyword before type (T-SQL allows @param AS int)
        m = re.match(
            r'@(\w+)\s+'
            r'(?:AS\s+)?'                    # optional AS keyword
            r'([\w]+(?:\s*\([^)]*\))?)'      # type with optional (precision)
            r'(?:\s*=\s*([^,]+?))?'           # optional default (non-greedy)
            r'(?:\s+(OUTPUT|OUT))?\s*$',       # optional OUTPUT
            part, re.IGNORECASE
        )
        if m:
            name = m.group(1)
            raw_type = m.group(2).strip()
            default = m.group(3)
            is_output = m.group(4) is not None

            pg_type = convert_type(raw_type)
            pg_name = f"p_{name}"

            if default:
                default = default.strip()
                default = re.sub(r"(?i)\bNULL\b", "NULL", default)
                default = re.sub(r"(?i)\bGETDATE\s*\(\)", "CURRENT_TIMESTAMP", default)

            params.append(ProcParam(
                name=f"@{name}",
                pg_name=pg_name,
                data_type=pg_type,
                is_output=is_output,
                default_value=default
            ))
        else:
            # Could not parse - log warning but don't use p_unknown
            # Try a more lenient parse
            m2 = re.match(r'@(\w+)\s+(.+?)(?:\s+(OUTPUT|OUT))?\s*$', part, re.IGNORECASE)
            if m2:
                name = m2.group(1)
                raw_type = re.sub(r'(?i)^\s*AS\s+', '', m2.group(2).strip())
                # Remove default value if present
                default = None
                if '=' in raw_type:
                    raw_type, default = raw_type.split('=', 1)
                    raw_type = raw_type.strip()
                    default = default.strip()
                is_output = m2.group(3) is not None
                pg_type = convert_type(raw_type)
                pg_name = f"p_{name}"
                if default:
                    default = re.sub(r"(?i)\bNULL\b", "NULL", default)
                    default = re.sub(r"(?i)\bGETDATE\s*\(\)", "CURRENT_TIMESTAMP", default)
                params.append(ProcParam(
                    name=f"@{name}",
                    pg_name=pg_name,
                    data_type=pg_type,
                    is_output=is_output,
                    default_value=default
                ))
            else:
                params.append(ProcParam(
                    name=part,
                    pg_name="p_unknown",
                    data_type="text",
                    is_output=False,
                    default_value=None
                ))

    return params


# --- Statement Splitter ---

def split_into_statements(body: str) -> List[str]:
    """
    Split T-SQL body into logical statements.
    Handles multi-line statements by joining lines until we hit a statement boundary.
    Key fix: SET after UPDATE is a continuation, not a new statement.
    """
    # Remove block comments first
    body = re.sub(r'/\*.*?\*/', '', body, flags=re.DOTALL)

    lines = body.split('\n')
    statements = []
    current = []

    # Track if previous accumulated statement starts with UPDATE (for SET continuation)
    def current_starts_with_update():
        """Check if the current accumulated lines start with an UPDATE statement"""
        if not current:
            return False
        first = current[0].strip().lower()
        return first.startswith('update')

    # Track if previous statement ends with UNION ALL or UNION (continuation of SELECT)
    def current_ends_with_union():
        if not current:
            return False
        last = current[-1].strip().lower()
        return last.endswith('union all') or last.endswith('union')

    # Track if previous accumulated statement starts with SELECT
    def current_starts_with_select():
        if not current:
            return False
        first = current[0].strip().lower()
        return first.startswith('select')

    # Keywords that start new statements
    STMT_STARTERS = re.compile(
        r'(?i)^\s*(?:'
        r'SELECT\b|INSERT\b|UPDATE\b|DELETE\b|MERGE\b|'
        r'DECLARE\b|SET\b|'
        r'IF\b|ELSE\b|WHILE\b|'
        r'BEGIN\b|END\b|'
        r'RETURN\b|GOTO\b|'
        r'EXEC\b|EXECUTE\b|'
        r'PRINT\b|RAISERROR\b|'
        r'OPEN\b|CLOSE\b|FETCH\b|DEALLOCATE\b|'
        r'CREATE\b|DROP\b|ALTER\b|TRUNCATE\b|'
        r'COMMIT\b|ROLLBACK\b'
        r')'
    )

    # Control flow markers (standalone, not multi-line)
    CONTROL_FLOW = re.compile(
        r'(?i)^\s*(?:'
        r'BEGIN\s*$|BEGIN\s+TRY|BEGIN\s+CATCH|BEGIN\s+TRAN|'
        r'END\s*;?\s*$|END\s+TRY|END\s+CATCH|'
        r'ELSE\s*$|ELSE\s+BEGIN|ELSE\s+IF|'
        r'RETURN\s*;?\s*$|RETURN\s+-?\d|RETURN\s+@\w+|'
        r'GOTO\s+\w+|'
        r'COMMIT|ROLLBACK|'
        r'OPEN\s+\w+|CLOSE\s+\w+|DEALLOCATE\s+\w+'
        r')'
    )

    for line in lines:
        stripped = line.strip()

        # Skip empty lines and single-line comments
        if not stripped or stripped.startswith('--'):
            continue

        # Strip trailing inline comments (-- style) before joining
        if '--' in stripped:
            in_quote = False
            quote_char = None
            for ci in range(len(stripped) - 1):
                ch = stripped[ci]
                if ch in ("'", '"') and not in_quote:
                    in_quote = True
                    quote_char = ch
                elif ch == quote_char and in_quote:
                    in_quote = False
                elif stripped[ci:ci+2] == '--' and not in_quote:
                    stripped = stripped[:ci].rstrip()
                    break

        if not stripped:
            continue

        # Check if this line starts a new statement
        prev_ends_comma = current and current[-1].rstrip().endswith(',')

        # Key fix: SET after UPDATE is a continuation of the UPDATE, not a new SET statement
        # But SET after UPDATE...WHERE is a NEW statement (variable assignment, not column SET)
        def _update_has_where():
            """Check if the current UPDATE statement already has a WHERE clause"""
            if not current:
                return False
            joined_lower = ' '.join(current).lower()
            return ' where ' in joined_lower

        is_set_after_update = (
            re.match(r'(?i)^\s*SET\b', stripped) and
            current_starts_with_update() and
            # Make sure it's a column assignment SET, not SET NOCOUNT etc.
            not re.match(r'(?i)^\s*SET\s+(?:NOCOUNT|XACT_ABORT|ANSI|QUOTED|TRANSACTION|ROWCOUNT)\b', stripped) and
            # SET after WHERE is a new statement (SET @var = @@ROWCOUNT)
            not _update_has_where()
        )

        # Also handle: WHERE/JOIN/ON/AND/OR/FROM/ORDER/GROUP/HAVING after DML
        is_sql_continuation = (
            re.match(r'(?i)^\s*(?:WHERE\b|AND\b|OR\b|JOIN\b|ON\b|FROM\b|ORDER\b|GROUP\b|HAVING\b|INNER\b|LEFT\b|RIGHT\b|CROSS\b|FULL\b|UNION\b|VALUES\b|INTO\b|OUTPUT\b)', stripped) and
            current
        )

        # Handle UNION ALL continuation: SELECT ... UNION ALL + next SELECT
        is_union_continuation = (
            re.match(r'(?i)^\s*SELECT\b', stripped) and
            current_ends_with_union()
        )

        # Handle CURSOR FOR continuation: DECLARE cursor CURSOR FOR + SELECT
        is_cursor_continuation = (
            re.match(r'(?i)^\s*SELECT\b', stripped) and
            current and
            re.search(r'(?i)\bCURSOR\s+(?:(?:LOCAL|GLOBAL|FORWARD_ONLY|STATIC|DYNAMIC|FAST_FORWARD|SCROLL)\s+)*FOR\s*$', ' '.join(current))
        )

        # Handle INSERT...SELECT continuation: INSERT INTO table SELECT ...
        # SELECT after INSERT (without VALUES already present) is a continuation
        def current_starts_with_insert():
            if not current:
                return False
            first = current[0].strip().lower()
            return first.startswith('insert')

        is_insert_select_continuation = (
            re.match(r'(?i)^\s*SELECT\b', stripped) and
            current_starts_with_insert() and
            not re.search(r'(?i)\bVALUES\b', ' '.join(current)) and
            not re.search(r'(?i)\bSELECT\b', ' '.join(current))
        )

        # Handle open parenthesis continuation: if the previous line ends with ( or the
        # accumulated text has unbalanced parentheses, this is a continuation
        is_paren_continuation = False
        if current:
            joined = ' '.join(current)
            open_count = joined.count('(')
            close_count = joined.count(')')
            if open_count > close_count:
                is_paren_continuation = True

        if is_set_after_update or is_sql_continuation or is_union_continuation or is_paren_continuation or is_cursor_continuation or is_insert_select_continuation:
            # Continue the current statement
            current.append(stripped)
        elif STMT_STARTERS.match(stripped) and current and not prev_ends_comma:
            # Flush previous statement
            stmt = ' '.join(current)
            if stmt.strip():
                statements.append(stmt.strip())
            current = [stripped]
        elif current:
            # Continue previous multi-line statement
            current.append(stripped)
        else:
            # Start new
            current = [stripped]

        # Check if line ends with semicolon -> definitely end of statement
        if stripped.rstrip().endswith(';'):
            stmt = ' '.join(current)
            if stmt.strip():
                statements.append(stmt.strip().rstrip(';'))
            current = []
        # Check if this is a standalone control flow -> flush immediately
        elif CONTROL_FLOW.match(stripped) and len(current) == 1:
            stmt = ' '.join(current)
            if stmt.strip():
                statements.append(stmt.strip())
            current = []

    # Flush remaining
    if current:
        stmt = ' '.join(current)
        if stmt.strip():
            statements.append(stmt.strip())

    return statements


# --- Expression Conversion ---

def split_args(args_str: str) -> List[str]:
    """Split function arguments respecting parentheses nesting"""
    parts = []
    depth = 0
    current = []
    for ch in args_str:
        if ch == '(':
            depth += 1
            current.append(ch)
        elif ch == ')':
            depth -= 1
            current.append(ch)
        elif ch == ',' and depth == 0:
            parts.append(''.join(current))
            current = []
        else:
            current.append(ch)
    if current:
        parts.append(''.join(current))
    return parts


def convert_expression(expr: str, param_map: dict) -> str:
    """Convert T-SQL expressions to PG equivalents"""
    if not expr:
        return expr

    # Replace @@ system variables first (before @variable replacement)
    expr = re.sub(r'@@ROWCOUNT', 'v_rowcount', expr, flags=re.IGNORECASE)
    expr = re.sub(r'@@FETCH_STATUS\s*=\s*0', 'v_fetch_found', expr, flags=re.IGNORECASE)
    expr = re.sub(r'@@FETCH_STATUS\s*<>\s*0', 'NOT v_fetch_found', expr, flags=re.IGNORECASE)
    expr = re.sub(r'@@FETCH_STATUS', 'v_fetch_status', expr, flags=re.IGNORECASE)
    expr = re.sub(r'@@ERROR', '0 /* @@ERROR */', expr, flags=re.IGNORECASE)
    expr = re.sub(r'@@IDENTITY', 'LASTVAL()', expr, flags=re.IGNORECASE)

    # Replace @variable references with pg names
    def replace_var(m):
        var = m.group(1)
        lower = var.lower()
        if lower in param_map:
            return param_map[lower]
        return f"v_{var}"
    expr = re.sub(r'@(\w+)', replace_var, expr)

    # Remove square brackets around identifiers
    expr = re.sub(r'\[([^\]]+)\]', r'\1', expr)

    # Remove schema prefix dbo.
    expr = re.sub(r'(?i)\bdbo\.', '', expr)

    # GETDATE() -> CURRENT_TIMESTAMP
    expr = re.sub(r'(?i)\bGETDATE\s*\(\)', 'CURRENT_TIMESTAMP', expr)

    # GETUTCDATE() -> (CURRENT_TIMESTAMP AT TIME ZONE 'UTC')
    expr = re.sub(r'(?i)\bGETUTCDATE\s*\(\)', "(CURRENT_TIMESTAMP AT TIME ZONE 'UTC')", expr)

    # NEWID() -> gen_random_uuid()
    expr = re.sub(r'(?i)\bNEWID\s*\(\)', 'gen_random_uuid()', expr)

    # ISNULL(a, b) -> COALESCE(a, b)
    expr = re.sub(r'(?i)\bISNULL\s*\(', 'COALESCE(', expr)

    # LEN(s) -> LENGTH(s)
    expr = re.sub(r'(?i)\bLEN\s*\(', 'LENGTH(', expr)

    # CHARINDEX(sub, s) -> POSITION(sub IN s)
    def convert_charindex(m):
        args = m.group(1)
        parts = split_args(args)
        if len(parts) >= 2:
            return f"POSITION({parts[0].strip()} IN {parts[1].strip()})"
        return m.group(0)
    expr = re.sub(r'(?i)\bCHARINDEX\s*\(([^)]+)\)', convert_charindex, expr)

    # SUBSTRING(s, start, len) -> SUBSTRING(s FROM start FOR len)
    def convert_substring(m):
        args = m.group(1)
        parts = split_args(args)
        if len(parts) == 3:
            return f"SUBSTRING({parts[0].strip()} FROM {parts[1].strip()} FOR {parts[2].strip()})"
        return m.group(0)
    expr = re.sub(r'(?i)\bSUBSTRING\s*\(([^)]+)\)', convert_substring, expr)

    # CONVERT(type, val [, style]) -> CAST or TO_CHAR
    # Handle nested parentheses properly
    def convert_convert_balanced(expr_str):
        """Find and convert CONVERT(...) calls handling nested parens"""
        result = []
        i = 0
        lower = expr_str.lower()
        while i < len(expr_str):
            # Find CONVERT(
            pos = lower.find('convert(', i)
            if pos == -1:
                result.append(expr_str[i:])
                break
            # Make sure it's a word boundary before CONVERT
            if pos > 0 and (expr_str[pos-1].isalnum() or expr_str[pos-1] == '_'):
                result.append(expr_str[i:pos+8])
                i = pos + 8
                continue
            result.append(expr_str[i:pos])
            # Find matching closing paren
            start = pos + 8  # after 'CONVERT('
            depth = 1
            j = start
            while j < len(expr_str) and depth > 0:
                if expr_str[j] == '(':
                    depth += 1
                elif expr_str[j] == ')':
                    depth -= 1
                j += 1
            if depth != 0:
                # Unbalanced - keep as is
                result.append(expr_str[pos:j])
                i = j
                continue
            inner = expr_str[start:j-1]
            parts = split_args(inner)
            if len(parts) >= 3:
                # CONVERT(type, val, style) - date formatting
                type_str = parts[0].strip().lower()
                val = parts[1].strip()
                style = parts[2].strip()
                if type_str in ('varchar', 'nvarchar', 'char') or re.match(r'(?i)varchar\s*\(\d+\)', type_str):
                    # Date formatting with style
                    style_map = {
                        '120': 'YYYY-MM-DD HH24:MI:SS',
                        '121': 'YYYY-MM-DD HH24:MI:SS.MS',
                        '112': 'YYYYMMDD',
                        '111': 'YYYY/MM/DD',
                        '110': 'MM-DD-YYYY',
                        '108': 'HH24:MI:SS',
                        '107': 'Mon DD, YYYY',
                        '106': 'DD Mon YYYY',
                        '105': 'DD-MM-YYYY',
                        '104': 'DD.MM.YYYY',
                        '103': 'DD/MM/YYYY',
                        '102': 'YYYY.MM.DD',
                        '101': 'MM/DD/YYYY',
                        '23': 'YYYY-MM-DD',
                    }
                    fmt = style_map.get(style, 'YYYY-MM-DD HH24:MI:SS')
                    result.append(f"TO_CHAR({val}, '{fmt}')")
                else:
                    pg_type = convert_type(parts[0].strip())
                    result.append(f"CAST({val} AS {pg_type})")
            elif len(parts) == 2:
                pg_type = convert_type(parts[0].strip())
                result.append(f"CAST({parts[1].strip()} AS {pg_type})")
            else:
                result.append(f"CONVERT({inner})")
            i = j
            lower = expr_str.lower()
        return ''.join(result)

    expr = convert_convert_balanced(expr)

    # CAST with T-SQL types -> PG types (handle balanced parens)
    def convert_cast(m):
        val = m.group(1).strip()
        tsql_type = m.group(2).strip()
        pg_type = convert_type(tsql_type)
        return f"CAST({val} AS {pg_type})"
    expr = re.sub(r'(?i)\bCAST\s*\(\s*(.+?)\s+AS\s+([\w]+(?:\s*\([^)]*\))?)\s*\)', convert_cast, expr)

    # DATEADD(unit, n, date) -> date + INTERVAL
    def convert_dateadd(m):
        args = m.group(1)
        parts = split_args(args)
        if len(parts) == 3:
            unit = parts[0].strip().lower()
            n = parts[1].strip()
            date_expr = parts[2].strip()
            unit_map = {
                'year': 'year', 'yy': 'year', 'yyyy': 'year',
                'month': 'month', 'mm': 'month', 'm': 'month',
                'day': 'day', 'dd': 'day', 'd': 'day',
                'hour': 'hour', 'hh': 'hour',
                'minute': 'minute', 'mi': 'minute', 'n': 'minute',
                'second': 'second', 'ss': 'second', 's': 'second',
                'week': 'week', 'wk': 'week', 'ww': 'week',
                'quarter': 'month',
            }
            pg_unit = unit_map.get(unit, unit)
            if unit in ('quarter', 'qq', 'q'):
                return f"({date_expr} + ({n}) * INTERVAL '3 months')"
            if re.match(r'^-?\d+$', n):
                return f"({date_expr} + INTERVAL '{n} {pg_unit}s')"
            else:
                return f"({date_expr} + ({n}) * INTERVAL '1 {pg_unit}')"
        return m.group(0)
    expr = re.sub(r'(?i)\bDATEADD\s*\(([^)]+)\)', convert_dateadd, expr)

    # DATEDIFF(unit, d1, d2) -> EXTRACT based
    def convert_datediff(m):
        args = m.group(1)
        parts = split_args(args)
        if len(parts) == 3:
            unit = parts[0].strip().lower()
            d1 = parts[1].strip()
            d2 = parts[2].strip()
            divisor_map = {
                'second': 1, 'ss': 1, 's': 1,
                'minute': 60, 'mi': 60, 'n': 60,
                'hour': 3600, 'hh': 3600,
                'day': 86400, 'dd': 86400, 'd': 86400,
                'week': 604800, 'wk': 604800, 'ww': 604800,
            }
            divisor = divisor_map.get(unit)
            if divisor is not None:
                if divisor == 1:
                    return f"EXTRACT(EPOCH FROM ({d2})::timestamp - ({d1})::timestamp)::integer"
                return f"(EXTRACT(EPOCH FROM ({d2})::timestamp - ({d1})::timestamp) / {divisor})::integer"
            elif unit in ('month', 'mm', 'm'):
                return f"(EXTRACT(YEAR FROM AGE(({d2})::timestamp, ({d1})::timestamp)) * 12 + EXTRACT(MONTH FROM AGE(({d2})::timestamp, ({d1})::timestamp)))::integer"
            elif unit in ('year', 'yy', 'yyyy'):
                return f"EXTRACT(YEAR FROM AGE(({d2})::timestamp, ({d1})::timestamp))::integer"
        return m.group(0)
    expr = re.sub(r'(?i)\bDATEDIFF\s*\(([^)]+)\)', convert_datediff, expr)

    # SCOPE_IDENTITY() -> LASTVAL()
    expr = re.sub(r'(?i)\bSCOPE_IDENTITY\s*\(\)', 'LASTVAL()', expr)

    # Remove ALL table hints: WITH (NOLOCK), WITH(NOLOCK), WITH(INDEX(...)), (NOLOCK), (UPDLOCK), etc.
    # Comprehensive pattern covering all SQL Server lock hint variants
    _LOCK_HINTS = r'NOLOCK|UPDLOCK|ROWLOCK|HOLDLOCK|TABLOCK|TABLOCKX|PAGLOCK|READPAST|READUNCOMMITTED|READCOMMITTED|REPEATABLEREAD|SERIALIZABLE|XLOCK'
    expr = re.sub(
        r'(?i)\s*WITH\s*\(\s*(?:' + _LOCK_HINTS + r'|INDEX\s*(?:\([^)]*\)|=\w+))'
        r'(?:\s*,\s*(?:' + _LOCK_HINTS + r'|INDEX\s*(?:\([^)]*\)|=\w+)))*\s*\)',
        '', expr
    )
    # Remove standalone (NOLOCK), (UPDLOCK) etc. after table names/aliases
    expr = re.sub(
        r'(?i)\(\s*(?:' + _LOCK_HINTS + r')(?:\s*,\s*(?:' + _LOCK_HINTS + r'))*\s*\)',
        '', expr
    )

    # XACT_STATE() -> 0
    expr = re.sub(r'(?i)\bXACT_STATE\s*\(\)', '0', expr)

    # Compound assignment operators: col += val -> col = col + val, col -= val -> col = col - val
    # This must be done in UPDATE SET context
    def fix_compound_assign(m):
        col = m.group(1).strip()
        op = m.group(2)
        val = m.group(3).strip()
        base_op = op[0]  # + or -
        return f"{col} = {col} {base_op} {val}"
    expr = re.sub(r'(\b\w+)\s*(\+=|-=)\s*(\S+)', fix_compound_assign, expr)

    # Bitwise OR assignment: col |= val -> col = col | val
    def fix_bitor_assign(m):
        col = m.group(1).strip()
        val = m.group(2).strip()
        return f"{col} = {col} | {val}"
    expr = re.sub(r'(\b\w+)\s*\|=\s*(\S+)', fix_bitor_assign, expr)

    # String concatenation: + -> || (only when adjacent to string literals or CAST to varchar)
    # Do NOT blindly convert v_a + v_b → v_a::text || v_b::text as it breaks arithmetic
    expr = re.sub(r"'\s*\+\s*", "' || ", expr)
    expr = re.sub(r"\s*\+\s*'", " || '", expr)
    # CAST(...AS varchar) + expr → CAST(...) || expr (clearly string context)
    expr = re.sub(r'(\bCAST\([^)]+AS\s+(?:varchar|text|char)[^)]*\))\s*\+\s*', r'\1 || ', expr)
    expr = re.sub(r'\s*\+\s*(\bCAST\([^)]+AS\s+(?:varchar|text|char)[^)]*\))', r' || \1', expr)

    # Remove N prefix from string literals: N'text' -> 'text'
    expr = re.sub(r"\bN'", "'", expr)

    # Fix integer to bytea cast: CAST(x AS bytea) -> binary(x) if x is integer-like
    def fix_bytea_cast(m):
        val = m.group(1).strip()
        if re.match(r'^[pv]_\w+$|^\d+$', val):
            return f"binary({val})"
        return m.group(0)
    expr = re.sub(r'(?i)\bCAST\s*\(\s*([^)]+)\s+AS\s+bytea\s*\)', fix_bytea_cast, expr)

    # SELECT TOP N -> SELECT ... LIMIT N (in subqueries too)
    def convert_top_in_expr(expr_str):
        """Convert all SELECT TOP N occurrences, including in subqueries"""
        # Pattern: SELECT TOP (N) or SELECT TOP N
        def replace_top(m):
            prefix = m.group(1) or ''
            n = m.group(2) or m.group(3)
            return f"SELECT {prefix}"  # We'll add LIMIT later at the statement level
        # Handle TOP (expr) with parens
        result = re.sub(r'(?i)\bSELECT\s+(?:(DISTINCT)\s+)?TOP\s*\(\s*(\w+)\s*\)', replace_top, expr_str)
        # Handle TOP N without parens
        result = re.sub(r'(?i)\bSELECT\s+(?:(DISTINCT)\s+)?TOP\s+(\d+)\b', replace_top, result)
        return result
    # Don't apply here - we'll handle TOP at statement level more carefully
    # expr = convert_top_in_expr(expr)

    # String alias: SELECT col AS 'alias' -> SELECT col AS alias
    # Must handle case-insensitive AS and run BEFORE the bare 'alias' rule
    expr = re.sub(r"(?i)(?<=\s)AS\s+'(\w+)'", r'AS \1', expr)
    # col 'alias' pattern (identifier or ) followed by space then single-quoted word used as alias)
    # Only match when NOT preceded by AS (case-insensitive) to avoid double AS
    expr = re.sub(r"(?<![Aa][Ss]\s)(\w)\s+'(\w+)'(?=\s*(?:,|\bFROM\b|$))", r'\1 AS \2', expr)

    # Convert SELECT TOP N in inline subexpressions: (SELECT TOP 1 ... FROM ...)
    # This handles cases like v_x := (SELECT TOP 1 col FROM table)
    def convert_inline_top(m):
        distinct = m.group(1) or ''
        n = m.group(2) or m.group(3)
        return f"(SELECT {distinct}".strip() + f" /*INLINE_LIMIT:{n}*/"
    expr = re.sub(r'(?i)\(\s*SELECT\s+(?:(DISTINCT)\s+)?TOP\s*\(\s*([^)]+)\s*\)', convert_inline_top, expr)
    expr = re.sub(r'(?i)\(\s*SELECT\s+(?:(DISTINCT)\s+)?TOP\s+(\d+)\b', convert_inline_top, expr)

    # Place LIMIT before closing paren for inline subqueries
    while '/*INLINE_LIMIT:' in expr:
        m = re.search(r'/\*INLINE_LIMIT:([^*]+)\*/', expr)
        if not m:
            break
        n_val = m.group(1)
        placeholder = m.group(0)
        pos = m.start()
        expr = expr[:pos] + expr[pos + len(placeholder):]
        # Find the matching closing paren
        depth = 1  # We already consumed the opening (
        i = pos
        end_pos = len(expr)
        while i < len(expr):
            if expr[i] == '(':
                depth += 1
            elif expr[i] == ')':
                depth -= 1
                if depth == 0:
                    end_pos = i
                    break
            i += 1
        expr = expr[:end_pos] + f" LIMIT {n_val}" + expr[end_pos:]

    return expr


# --- SELECT TOP N Conversion (handles subqueries) ---

def convert_all_top_n(stmt: str) -> str:
    """
    Convert all SELECT TOP N patterns in a statement to LIMIT N.
    Handles top-level and nested subqueries.
    Works by finding each SELECT TOP N and placing LIMIT N before the
    closing paren of the subquery or at the end of the statement.
    """
    # First handle SELECT TOP (var) with parenthesized expressions
    def replace_top_paren(m):
        distinct = m.group(1) or ''
        n = m.group(2)
        # Store N for later placement
        prefix = f"SELECT {distinct}".strip()
        return f"{prefix} /*LIMIT_PLACEHOLDER:{n}*/"

    # Handle SELECT TOP (expr)
    result = re.sub(r'(?i)\bSELECT\s+(?:(DISTINCT)\s+)?TOP\s*\(\s*([^)]+)\s*\)', replace_top_paren, stmt)
    # Handle SELECT TOP N (number)
    result = re.sub(r'(?i)\bSELECT\s+(?:(DISTINCT)\s+)?TOP\s+(\d+)\b', replace_top_paren, result)

    # Now we need to place LIMIT N at the right position
    # For each placeholder, find where the SELECT statement ends (before closing paren or end)
    while '/*LIMIT_PLACEHOLDER:' in result:
        m = re.search(r'/\*LIMIT_PLACEHOLDER:([^*]+)\*/', result)
        if not m:
            break
        n_val = m.group(1)
        placeholder = m.group(0)
        pos = m.start()

        # Remove the placeholder
        result = result[:pos] + result[pos + len(placeholder):]

        # Find the end of this SELECT's scope
        # Walk forward from pos, tracking paren depth
        depth = 0
        found_from = False
        end_pos = len(result)
        i = pos
        while i < len(result):
            ch = result[i]
            if ch == '(':
                depth += 1
            elif ch == ')':
                if depth == 0:
                    # This closing paren ends our subquery
                    end_pos = i
                    break
                depth -= 1
            elif ch == ';':
                end_pos = i
                break
            i += 1

        # Insert LIMIT before the end position
        limit_clause = f" LIMIT {n_val}"
        result = result[:end_pos] + limit_clause + result[end_pos:]

    return result


# --- SELECT Assignment Parser (handles commas inside parentheses) ---

def _parse_select_assignment(stmt: str):
    """
    Parse SELECT @var = expr [, @var2 = expr2 ...] [FROM ...] patterns.
    Returns ([(var_name, expr), ...], from_clause_or_None) or None if not an assignment SELECT.
    Handles commas inside parentheses (e.g. COALESCE(x,y), CONVERT(type, val)).
    """
    # Must start with SELECT and have @var = pattern
    m = re.match(r'(?i)^SELECT\s+', stmt)
    if not m:
        return None

    rest = stmt[m.end():]

    # Quick check: must contain @var = somewhere near the start
    if not re.match(r'\s*@\w+\s*=', rest):
        return None

    # Split into tokens respecting parentheses depth
    # Find all @var = expr pairs separated by top-level commas, then FROM
    pairs = []
    pos = 0
    while pos < len(rest):
        # Try to match @var = at current position
        var_m = re.match(r'\s*@(\w+)\s*=\s*', rest[pos:])
        if not var_m:
            break
        var_name = var_m.group(1)
        expr_start = pos + var_m.end()

        # Scan forward to find the end of this expression:
        # top-level comma (next assignment) or top-level FROM keyword
        depth = 0
        i = expr_start
        expr_end = len(rest)
        found_from = False
        while i < len(rest):
            ch = rest[i]
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif ch == "'" :
                # Skip string literals
                i += 1
                while i < len(rest) and rest[i] != "'":
                    i += 1
            elif depth == 0:
                if ch == ',':
                    # Check if next token is @var = (another assignment)
                    after_comma = rest[i+1:]
                    if re.match(r'\s*@\w+\s*=', after_comma):
                        expr_end = i
                        break
                # Check for top-level FROM keyword (word boundary)
                if ch.upper() == 'F' and rest[i:i+4].upper() == 'FROM':
                    # Make sure it's a word boundary
                    before_ok = (i == 0 or not rest[i-1].isalnum() and rest[i-1] != '_')
                    after_ok = (i + 4 >= len(rest) or not rest[i+4].isalnum() and rest[i+4] != '_')
                    if before_ok and after_ok:
                        expr_end = i
                        found_from = True
                        break
            i += 1

        expr_val = rest[expr_start:expr_end].strip()
        if expr_val:
            pairs.append((var_name, expr_val))

        if found_from:
            from_clause = rest[expr_end + 4:].strip()
            return (pairs, from_clause) if pairs else None

        # Move past the comma to next assignment
        pos = expr_end + 1 if expr_end < len(rest) else len(rest)

    if pairs:
        # No FROM found - simple assignment
        return (pairs, None)

    return None


# --- Statement-level Conversion ---

def convert_statements(body: str, param_map: dict, proc_name: str) -> Tuple[str, List[str], List[str], Confidence]:
    """
    Convert T-SQL body into PL/pgSQL.
    Returns (body_text, declare_lines, warnings, confidence).
    """
    warnings = []
    confidence = Confidence.AUTO
    indent = "    "
    declare_lines = []
    body_lines = []

    body_lower = body.lower()
    uses_rowcount = '@@rowcount' in body_lower
    uses_goto = bool(re.search(r'(?i)\bGOTO\s+\w+', body))
    has_cursor = 'cursor' in body_lower and 'fetch' in body_lower
    has_output_into = bool(re.search(r'(?i)\bOUTPUT\s+(?:inserted|deleted)\.', body))

    if uses_goto:
        warnings.append("GOTO statements detected - converted to RETURN where possible")
        confidence = max_confidence(confidence, Confidence.REVIEW)
    if has_cursor:
        warnings.append("CURSOR logic detected - converted to PG cursor syntax")
        confidence = max_confidence(confidence, Confidence.REVIEW)
        declare_lines.append(f"{indent}v_fetch_found boolean := true;")
    if has_output_into:
        warnings.append("OUTPUT inserted/deleted clause detected - needs manual RETURNING conversion")
        confidence = max_confidence(confidence, Confidence.MANUAL)
    if uses_rowcount:
        declare_lines.append(f"{indent}v_rowcount integer := 0;")

    stmts = split_into_statements(body)

    prev_was_dml = False
    stmt_idx = -1
    # Track single-line IF: when IF is followed by a non-BEGIN statement,
    # we auto-close with END IF after that statement
    pending_end_if = 0  # Count of END IFs to insert after next statement

    # Helper: peek at next meaningful statement (skip SET NOCOUNT etc.)
    def peek_next(from_idx):
        """Look ahead to find the next meaningful statement after from_idx"""
        j = from_idx + 1
        while j < len(stmts):
            s = stmts[j].strip().lower()
            if re.match(r'(?i)^SET\s+(?:NOCOUNT|XACT_ABORT|ANSI)', s):
                j += 1
                continue
            return stmts[j].strip()
            break
        return ""

    def emit_pending_end_ifs():
        """Emit any pending END IF closings for single-line IF statements"""
        nonlocal pending_end_if
        while pending_end_if > 0:
            body_lines.append(f"{indent}END IF;")
            pending_end_if -= 1

    while stmt_idx < len(stmts) - 1:
        stmt_idx += 1
        stmt = stmts[stmt_idx]
        lower = stmt.lower().strip()

        # Skip SET NOCOUNT, SET XACT_ABORT, SET TRANSACTION ISOLATION, SET ANSI_*
        if re.match(r'(?i)^SET\s+(?:NOCOUNT|XACT_ABORT|ANSI_WARNINGS|ANSI_NULLS|QUOTED_IDENTIFIER)\s+', stmt):
            prev_was_dml = False
            continue
        if re.match(r'(?i)^SET\s+TRANSACTION\s+ISOLATION\s+LEVEL\b', stmt):
            prev_was_dml = False
            continue

        # SET ROWCOUNT N -> comment (will be handled with LIMIT in queries)
        rowcount_match = re.match(r'(?i)^SET\s+ROWCOUNT\s+(\d+)', stmt)
        if rowcount_match:
            body_lines.append(f"{indent}-- SET ROWCOUNT {rowcount_match.group(1)} (handled via LIMIT in queries);")
            prev_was_dml = False
            continue

        # If current statement uses v_rowcount and prev was DML, inject GET DIAGNOSTICS
        if uses_rowcount and prev_was_dml and '@@rowcount' in stmt.lower():
            body_lines.append(f"{indent}GET DIAGNOSTICS v_rowcount = ROW_COUNT;")
            prev_was_dml = False

        # --- DECLARE ---
        decl_match = re.match(r'(?i)^DECLARE\s+(.+)$', stmt)
        if decl_match:
            decl_body = decl_match.group(1).strip()
            _convert_declare(decl_body, param_map, declare_lines, warnings, indent)
            prev_was_dml = False
            continue

        # --- SET @var = expr ---
        set_match = re.match(r'(?i)^SET\s+@(\w+)\s*=\s*(.+)$', stmt)
        if set_match:
            var = set_match.group(1)
            val = set_match.group(2).strip()
            pg_var = _resolve_var(var, param_map)
            val = convert_expression(val, param_map)
            body_lines.append(f"{indent}{pg_var} := {val};")
            emit_pending_end_ifs()
            prev_was_dml = False
            continue

        # --- SELECT @var = ... FROM ... (assignment) ---
        # Uses custom parser to handle commas inside parentheses (e.g. COALESCE(x,y))
        sel_assign_parsed = _parse_select_assignment(stmt)
        if sel_assign_parsed is not None:
            assign_pairs, from_clause = sel_assign_parsed
            if from_clause:
                # SELECT @var = expr, @var2 = expr2 FROM ...
                cols = []
                targets = []
                for var_name, expr in assign_pairs:
                    pg_var = _resolve_var(var_name, param_map)
                    col = convert_expression(expr, param_map)
                    cols.append(col)
                    targets.append(pg_var)
                from_clause = convert_expression(from_clause, param_map)
                body_lines.append(f"{indent}SELECT {', '.join(cols)} INTO {', '.join(targets)} FROM {from_clause};")
                emit_pending_end_ifs()
                prev_was_dml = True
            else:
                # SELECT @var = expr (no FROM, simple assignment)
                for var_name, expr in assign_pairs:
                    pg_var = _resolve_var(var_name, param_map)
                    val = convert_expression(expr, param_map)
                    body_lines.append(f"{indent}{pg_var} := {val};")
                emit_pending_end_ifs()
                prev_was_dml = False
            continue

        # --- BEGIN TRY ---
        if re.match(r'(?i)^BEGIN\s+TRY$', stmt):
            body_lines.append(f"{indent}BEGIN")
            prev_was_dml = False
            continue

        # --- END TRY ---
        if re.match(r'(?i)^END\s+TRY$', stmt):
            prev_was_dml = False
            continue

        # --- BEGIN CATCH ---
        if re.match(r'(?i)^BEGIN\s+CATCH$', stmt):
            body_lines.append(f"{indent}EXCEPTION WHEN OTHERS THEN")
            prev_was_dml = False
            continue

        # --- END CATCH ---
        if re.match(r'(?i)^END\s+CATCH$', stmt):
            body_lines.append(f"{indent}END;")
            prev_was_dml = False
            continue

        # --- BEGIN TRAN / TRANSACTION ---
        if re.match(r'(?i)^BEGIN\s+TRAN', stmt) or re.match(r'(?i)^TRANSACTION', stmt):
            body_lines.append(f"{indent}-- Transaction managed by PG function context")
            prev_was_dml = False
            continue

        # --- COMMIT ---
        if re.match(r'(?i)^COMMIT\b', stmt):
            body_lines.append(f"{indent}-- COMMIT (implicit in PG function)")
            prev_was_dml = False
            continue

        # --- ROLLBACK ---
        if re.match(r'(?i)^ROLLBACK\b', stmt):
            body_lines.append(f"{indent}RAISE EXCEPTION 'Rollback requested';")
            warnings.append("ROLLBACK TRANSACTION converted to RAISE EXCEPTION")
            confidence = max_confidence(confidence, Confidence.REVIEW)
            prev_was_dml = False
            continue

        # --- IF EXISTS / IF NOT EXISTS ---
        if_exists = re.match(r'(?i)^IF\s+(NOT\s+)?EXISTS\s*\((.+)\)$', stmt)
        if if_exists:
            neg = if_exists.group(1) or ""
            subq = convert_expression(if_exists.group(2).strip(), param_map)
            subq = convert_all_top_n(subq)
            body_lines.append(f"{indent}IF {neg.strip()+' ' if neg.strip() else ''}EXISTS ({subq}) THEN")
            # Check if next stmt is BEGIN (block IF) or not (single-line IF)
            next_s = peek_next(stmt_idx)
            if not re.match(r'(?i)^BEGIN$', next_s):
                pending_end_if += 1
            prev_was_dml = False
            continue

        # --- IF ... GOTO label (inline IF with GOTO) ---
        if_goto = re.match(r'(?i)^IF\s+(.+?)\s+GOTO\s+(\w+)$', stmt)
        if if_goto:
            cond = if_goto.group(1).strip()
            label = if_goto.group(2)
            cond = convert_expression(cond, param_map)
            body_lines.append(f"{indent}IF {cond} THEN")
            body_lines.append(f"{indent}    RETURN;  -- Originally: GOTO {label}")
            body_lines.append(f"{indent}END IF;")
            prev_was_dml = False
            continue

        # --- IF ... RETURN value (inline IF with RETURN) ---
        if_ret = re.match(r'(?i)^IF\s+(.+?)\s+RETURN\s+(.+)$', stmt)
        if if_ret and not re.match(r'(?i)^IF\s+(?:NOT\s+)?EXISTS', stmt):
            cond = if_ret.group(1).strip()
            ret_val = if_ret.group(2).strip()
            cond = convert_expression(cond, param_map)
            ret_val = convert_expression(ret_val, param_map)
            body_lines.append(f"{indent}IF {cond} THEN")
            body_lines.append(f"{indent}    RETURN {ret_val};")
            body_lines.append(f"{indent}END IF;")
            prev_was_dml = False
            continue

        # --- IF ... PRINT 'msg' (inline IF with PRINT) ---
        if_print = re.match(r"(?i)^IF\s+(.+?)\s+PRINT\s+(.+)$", stmt)
        if if_print:
            cond = convert_expression(if_print.group(1).strip(), param_map)
            msg = convert_expression(if_print.group(2).strip(), param_map)
            body_lines.append(f"{indent}IF {cond} THEN")
            body_lines.append(f"{indent}    RAISE NOTICE '%', {msg};")
            body_lines.append(f"{indent}END IF;")
            prev_was_dml = False
            continue

        # --- IF ... BEGIN -> IF ... THEN ---
        if_match = re.match(r'(?i)^IF\s+(.+?)(?:\s+BEGIN)?$', stmt)
        if if_match and not re.match(r'(?i)^IF\s+(?:NOT\s+)?EXISTS', stmt):
            cond = if_match.group(1).strip()
            has_begin = bool(re.search(r'(?i)\bBEGIN\s*$', stmt))
            cond = convert_expression(cond, param_map)
            body_lines.append(f"{indent}IF {cond} THEN")
            # If no BEGIN follows, this is a single-line IF
            if not has_begin:
                next_s = peek_next(stmt_idx)
                if not re.match(r'(?i)^BEGIN$', next_s):
                    pending_end_if += 1
            prev_was_dml = False
            continue

        # --- ELSE IF -> ELSIF ---
        elif_match = re.match(r'(?i)^ELSE\s+IF\s+(.+?)(?:\s+BEGIN)?$', stmt)
        if elif_match:
            # Remove preceding END IF from single-line IF if present
            if body_lines and body_lines[-1].strip() == 'END IF;':
                body_lines.pop()
            cond = convert_expression(elif_match.group(1).strip(), param_map)
            body_lines.append(f"{indent}ELSIF {cond} THEN")
            has_begin = bool(re.search(r'(?i)\bBEGIN\s*$', stmt))
            if not has_begin:
                next_s = peek_next(stmt_idx)
                if not re.match(r'(?i)^BEGIN$', next_s):
                    pending_end_if += 1
            prev_was_dml = False
            continue

        # --- ELSE ---
        if re.match(r'(?i)^ELSE(?:\s+BEGIN)?$', stmt):
            has_begin = bool(re.search(r'(?i)\bBEGIN\s*$', stmt))
            # If the previous output line was END IF; (from single-line IF),
            # remove it because the IF continues with ELSE
            if body_lines and body_lines[-1].strip() == 'END IF;':
                body_lines.pop()
            body_lines.append(f"{indent}ELSE")
            if not has_begin:
                next_s = peek_next(stmt_idx)
                if not re.match(r'(?i)^BEGIN$', next_s):
                    pending_end_if += 1
            prev_was_dml = False
            continue

        # --- BEGIN (standalone) ---
        if re.match(r'(?i)^BEGIN$', stmt):
            prev_was_dml = False
            continue

        # --- END ---
        if re.match(r'(?i)^END$', stmt):
            # Look ahead: if next statement is ELSE or ELSE IF, this END just closes
            # a BEGIN block inside an IF, so we should NOT emit END IF here.
            # In PL/pgSQL: IF...THEN...ELSE...END IF (no BEGIN/END blocks needed).
            next_stmt = peek_next(stmt_idx)
            next_lower = next_stmt.lower()
            if next_lower.startswith('else'):
                # This END closes a BEGIN block before ELSE - skip it in PG
                prev_was_dml = False
                continue
            end_type = _determine_end_type(body_lines)
            body_lines.append(f"{indent}{end_type}")
            prev_was_dml = False
            continue

        # --- WHILE ---
        while_match = re.match(r'(?i)^WHILE\s+(.+?)(?:\s+BEGIN)?$', stmt)
        if while_match:
            cond = convert_expression(while_match.group(1).strip(), param_map)
            body_lines.append(f"{indent}WHILE {cond} LOOP")
            prev_was_dml = False
            continue

        # --- RETURN value ---
        ret_val = re.match(r'(?i)^RETURN\s+(.+)$', stmt)
        if ret_val:
            val = convert_expression(ret_val.group(1).strip(), param_map)
            body_lines.append(f"{indent}RETURN {val};")
            emit_pending_end_ifs()
            prev_was_dml = False
            continue

        # --- RETURN (no value) ---
        if re.match(r'(?i)^RETURN$', stmt):
            body_lines.append(f"{indent}RETURN;")
            emit_pending_end_ifs()
            prev_was_dml = False
            continue

        # --- PRINT ---
        print_match = re.match(r'(?i)^PRINT\s+(.+)$', stmt)
        if print_match:
            msg = convert_expression(print_match.group(1).strip(), param_map)
            body_lines.append(f"{indent}RAISE NOTICE '%', {msg};")
            emit_pending_end_ifs()
            prev_was_dml = False
            continue

        # --- RAISERROR ---
        re_match = re.match(r'(?i)^RAISERROR\s*\((.+)\)$', stmt)
        if re_match:
            args = re_match.group(1).strip()
            parts = split_args(args)
            if parts:
                msg = convert_expression(parts[0].strip(), param_map)
                body_lines.append(f"{indent}RAISE EXCEPTION '%', {msg};")
            emit_pending_end_ifs()
            prev_was_dml = False
            continue

        # --- EXEC (@sql) or EXEC (variable) - dynamic SQL ---
        exec_dyn = re.match(r'(?i)^(?:EXEC|EXECUTE)\s*\(\s*(.+)\s*\)$', stmt)
        if exec_dyn:
            sql_expr = convert_expression(exec_dyn.group(1).strip(), param_map)
            body_lines.append(f"{indent}EXECUTE {sql_expr};")
            emit_pending_end_ifs()
            prev_was_dml = True
            continue

        # --- sp_executesql ---
        sp_exec = re.match(r'(?i)^(?:EXEC|EXECUTE)\s+sp_executesql\s+(.+)$', stmt)
        if sp_exec:
            args_str = convert_expression(sp_exec.group(1).strip(), param_map)
            body_lines.append(f"{indent}EXECUTE {args_str};")
            emit_pending_end_ifs()
            warnings.append("sp_executesql converted to EXECUTE - may need manual USING clause")
            confidence = max_confidence(confidence, Confidence.REVIEW)
            prev_was_dml = True
            continue

        # --- EXEC / EXECUTE procedure call ---
        # Match: EXEC [result =] [dbo.]procname args
        exec_assign = re.match(r'(?i)^(?:EXEC|EXECUTE)\s+@?(\w+)\s*=\s*(?:\[?dbo\]?\.)?\[?(\w+)\]?\s*(.*?)$', stmt)
        if exec_assign:
            ret_var = exec_assign.group(1)
            called_proc = exec_assign.group(2)
            args_str = exec_assign.group(3).strip()
            args_str = re.sub(r'(?i)\s+OUTPUT\b', '', args_str)
            args_str = re.sub(r'(?i)\s+OUT\b', '', args_str)
            args_str = re.sub(r'@\w+\s*=\s*', '', args_str)
            args_str = convert_expression(args_str, param_map)
            pg_var = _resolve_var(ret_var, param_map)
            body_lines.append(f"{indent}{pg_var} := {called_proc}({args_str});")
            emit_pending_end_ifs()
            prev_was_dml = True
            continue

        exec_match = re.match(r'(?i)^(?:EXEC|EXECUTE)\s+(?:\[?dbo\]?\.)?\[?(\w+)\]?\s*(.*?)$', stmt)
        if exec_match:
            called_proc = exec_match.group(1)
            args_str = exec_match.group(2).strip()
            args_str = re.sub(r'(?i)\s+OUTPUT\b', '', args_str)
            args_str = re.sub(r'(?i)\s+OUT\b', '', args_str)
            args_str = re.sub(r'@\w+\s*=\s*', '', args_str)
            args_str = convert_expression(args_str, param_map)
            body_lines.append(f"{indent}PERFORM {called_proc}({args_str});")
            emit_pending_end_ifs()
            prev_was_dml = True
            continue

        # --- OPEN cursor ---
        if re.match(r'(?i)^OPEN\s+(\w+)$', stmt):
            cursor_name = re.match(r'(?i)^OPEN\s+(\w+)', stmt).group(1)
            body_lines.append(f"{indent}OPEN {cursor_name};")
            prev_was_dml = False
            continue

        # --- FETCH NEXT FROM cursor INTO ---
        fetch_match = re.match(r'(?i)^FETCH\s+NEXT\s+FROM\s+(\w+)\s+INTO\s+(.+)$', stmt)
        if fetch_match:
            cursor_name = fetch_match.group(1)
            into_vars = convert_expression(fetch_match.group(2).strip(), param_map)
            body_lines.append(f"{indent}FETCH {cursor_name} INTO {into_vars};")
            body_lines.append(f"{indent}v_fetch_found := FOUND;")
            prev_was_dml = False
            continue

        # --- CLOSE cursor ---
        if re.match(r'(?i)^CLOSE\s+(\w+)$', stmt):
            cursor_name = re.match(r'(?i)^CLOSE\s+(\w+)', stmt).group(1)
            body_lines.append(f"{indent}CLOSE {cursor_name};")
            prev_was_dml = False
            continue

        # --- DEALLOCATE cursor (skip in PG) ---
        if re.match(r'(?i)^DEALLOCATE\s+', stmt):
            prev_was_dml = False
            continue

        # --- GOTO ---
        goto_match = re.match(r'(?i)^GOTO\s+(\w+)$', stmt)
        if goto_match:
            label = goto_match.group(1)
            body_lines.append(f"{indent}-- TODO: MANUAL REVIEW NEEDED - GOTO {label}")
            body_lines.append(f"{indent}RETURN;  -- Originally: GOTO {label}")
            emit_pending_end_ifs()
            prev_was_dml = False
            continue

        # --- Label: (including END_ROLLBACK: style labels) ---
        label_match = re.match(r'^(\w+)\s*:\s*$', stmt)
        if label_match:
            body_lines.append(f"{indent}-- Label: {label_match.group(1)}")
            prev_was_dml = False
            continue

        # --- CREATE TABLE #temp ---
        if re.match(r'(?i)^CREATE\s+TABLE\s+#', stmt):
            converted = convert_expression(stmt, param_map)
            converted = re.sub(r'(?i)\bCREATE\s+TABLE\s+#(\w+)', r'CREATE TEMP TABLE \1', converted)
            body_lines.append(f"{indent}{converted};")
            prev_was_dml = False
            continue

        # --- DROP TABLE #temp ---
        if re.match(r'(?i)^DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?#', stmt):
            converted = re.sub(r'#(\w+)', r'\1', stmt)
            converted = convert_expression(converted, param_map)
            if 'IF EXISTS' not in converted.upper():
                converted = re.sub(r'(?i)^DROP\s+TABLE\s+', 'DROP TABLE IF EXISTS ', converted)
            body_lines.append(f"{indent}{converted};")
            prev_was_dml = False
            continue

        # --- INSERT INTO ... EXEC proc -> INSERT INTO ... SELECT * FROM proc() ---
        insert_exec = re.match(
            r'(?i)^INSERT\s+(?:INTO\s+)?(\S+)\s+EXEC(?:UTE)?\s+(?:\[?dbo\]?\.)?\[?(\w+)\]?\s*(.*?)$',
            stmt
        )
        if insert_exec:
            table = insert_exec.group(1)
            proc = insert_exec.group(2)
            args = insert_exec.group(3).strip()
            args = convert_expression(args, param_map)
            table = re.sub(r'#(\w+)', r'\1', table)
            body_lines.append(f"{indent}INSERT INTO {table} SELECT * FROM {proc}({args});")
            warnings.append(f"INSERT...EXEC {proc} converted to INSERT...SELECT FROM {proc}() - verify return type")
            confidence = max_confidence(confidence, Confidence.REVIEW)
            prev_was_dml = True
            continue

        # --- General DML: INSERT, UPDATE, DELETE, SELECT ---
        converted = convert_expression(stmt, param_map)

        # Handle SELECT TOP N -> LIMIT N (including in subqueries)
        converted = convert_all_top_n(converted)

        # Handle SET ROWCOUNT remnants (just comment them)
        if re.match(r'(?i)^SET\s+ROWCOUNT\b', converted):
            body_lines.append(f"{indent}-- {converted}")
            prev_was_dml = False
            continue

        # Handle DELETE without FROM (SQL Server allows it)
        if re.match(r'(?i)^DELETE\s+(?!FROM\b)\w', converted):
            converted = re.sub(r'(?i)^DELETE\s+', 'DELETE FROM ', converted)

        # Handle INSERT without INTO (SQL Server allows it)
        if re.match(r'(?i)^INSERT\s+(?!INTO\b)\w', converted):
            converted = re.sub(r'(?i)^INSERT\s+', 'INSERT INTO ', converted)

        # Handle #temp table references
        converted = re.sub(r'#(\w+)', r'\1', converted)

        # Ensure trailing semicolon
        converted = converted.rstrip(';').strip() + ';'
        body_lines.append(f"{indent}{converted}")

        # Track DML for @@ROWCOUNT injection
        prev_was_dml = bool(re.match(r'(?i)^(?:INSERT|UPDATE|DELETE|SELECT)', converted))

        # Emit pending END IF after a non-control-flow statement
        while pending_end_if > 0:
            body_lines.append(f"{indent}END IF;")
            pending_end_if -= 1

    return '\n'.join(body_lines), declare_lines, warnings, confidence


def _resolve_var(name: str, param_map: dict) -> str:
    """Resolve a T-SQL variable name to its PG equivalent"""
    lower = name.lower()
    if lower in param_map:
        return param_map[lower]
    return f"v_{name}"


def _convert_declare(decl_body: str, param_map: dict, declare_lines: List[str],
                     warnings: List[str], indent: str):
    """Convert DECLARE statements and append to declare_lines"""
    # Handle cursor declaration
    # Remove optional @prefix from cursor name (T-SQL allows DECLARE @cur CURSOR)
    decl_stripped = re.sub(r'^@', '', decl_body.strip())
    cursor_match = re.match(
        r'(?i)(\w+)\s+CURSOR\s+(?:(?:LOCAL|GLOBAL|FORWARD_ONLY|STATIC|DYNAMIC|FAST_FORWARD|SCROLL|READ_ONLY|KEYSET)\s+)*FOR\s+(.+)$',
        decl_stripped
    )
    if cursor_match:
        cursor_name = cursor_match.group(1)
        query = cursor_match.group(2).strip()
        query = convert_expression(query, param_map)
        query = convert_all_top_n(query)
        declare_lines.append(f"{indent}{cursor_name} CURSOR FOR {query};")
        return

    # Handle table variables: @table TABLE (...)
    if re.search(r'(?i)\bTABLE\s*\(', decl_body):
        warnings.append("Table variable converted to temp table")
        declare_lines.append(f"{indent}-- TODO: MANUAL REVIEW NEEDED - Table variable: DECLARE {decl_body}")
        return

    # Handle compound DECLARE lines: @var1 type DECLARE @var2 type SET @var3 = val
    # Split on DECLARE keyword first
    if re.search(r'(?i)\bDECLARE\b', decl_body):
        sub_parts = re.split(r'(?i)\bDECLARE\b', decl_body)
        for sp in sub_parts:
            sp = sp.strip()
            if sp:
                # May also contain SET statements - split on SET
                if re.search(r'(?i)\bSET\b', sp):
                    set_parts = re.split(r'(?i)\bSET\b', sp)
                    if set_parts[0].strip():
                        _convert_declare(set_parts[0].strip(), param_map, declare_lines, warnings, indent)
                    # Remaining SET parts become body-level assignments - skip in DECLARE
                else:
                    _convert_declare(sp, param_map, declare_lines, warnings, indent)
        return

    # Split multiple declarations
    parts = re.split(r',\s*(?=@)', decl_body)
    for part in parts:
        part = part.strip()
        if not part:
            continue

        # Support optional AS keyword before type
        m = re.match(r'@(\w+)\s+(?:AS\s+)?([\w]+(?:\s*\([^)]*\))?)\s*(?:=\s*(.+?))?$', part, re.IGNORECASE)
        if m:
            var_name = m.group(1)
            raw_type = m.group(2).strip()
            default = m.group(3)
            pg_type = convert_type(raw_type)
            pg_var = f"v_{var_name}"

            if default:
                default = convert_expression(default.strip(), param_map)
                declare_lines.append(f"{indent}{pg_var} {pg_type} := {default};")
            else:
                declare_lines.append(f"{indent}{pg_var} {pg_type};")
        else:
            declare_lines.append(f"{indent}-- TODO: MANUAL REVIEW NEEDED - DECLARE {part}")


def _determine_end_type(body_lines: List[str]) -> str:
    """Determine whether END should be END IF, END LOOP, or END.
    Walks backward through body_lines to find the matching opener."""
    depth = 0
    found_if = False
    found_loop = False
    found_begin = False
    for i in range(len(body_lines) - 1, -1, -1):
        stripped = body_lines[i].strip()
        if stripped in ('END IF;', 'END LOOP;', 'END;'):
            depth += 1
        elif stripped.endswith('THEN') or stripped == 'ELSE' or stripped.startswith('ELSIF'):
            if depth > 0:
                depth -= 1
            else:
                return 'END IF;'
        elif stripped.endswith('LOOP'):
            if depth > 0:
                depth -= 1
            else:
                return 'END LOOP;'
        elif stripped == 'BEGIN':
            if depth > 0:
                depth -= 1
            else:
                return 'END;'
    # No matching opener found - this is likely a stray END.
    # Default to a comment rather than orphaned END IF
    return '-- END (no matching block);'


def _add_return_query_to_bare_selects(body_text: str, return_type: str) -> str:
    """
    Prefix bare SELECT statements in the body with RETURN QUERY or PERFORM.
    A 'bare' SELECT is one that:
      - starts with SELECT (at statement level, after indentation)
      - does NOT have INTO (variable assignment SELECT is already handled)
      - is NOT part of INSERT INTO ... SELECT (already handled)
      - is NOT inside IF EXISTS(...) (already handled)
      - is NOT a PERFORM (already handled)
    Also detects escaped assignment patterns (p_var = expr, v_var = expr)
    that slipped through sel_assign and converts them to SELECT INTO.
    """
    lines = body_text.split('\n')
    result = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        lower = stripped.lower()

        # Detect a bare SELECT statement: starts with SELECT, not SELECT ... INTO
        if re.match(r'(?i)^\s*SELECT\b', stripped):
            # Collect the full statement (may span multiple lines until semicolon)
            stmt_lines = [line]
            # Check if this line ends with semicolon
            while not stripped.rstrip().endswith(';') and i + 1 < len(lines):
                i += 1
                stmt_lines.append(lines[i])
                stripped = lines[i].strip()

            full_stmt = '\n'.join(stmt_lines)
            full_lower = full_stmt.lower()

            # Check if this is a bare SELECT (no INTO, not assignment, not subquery)
            has_into = bool(re.search(r'(?i)\bINTO\s+(?:v_|p_)', full_lower))
            is_insert_select = False  # INSERT ... SELECT is already separate

            # Check for escaped assignment pattern: SELECT p_var = expr FROM ...
            # This happens when sel_assign fails (e.g. commas in COALESCE)
            has_escaped_assign = bool(re.search(r'(?i)\bSELECT\s+[pv]_\w+\s*=\s*', full_stmt))

            if has_escaped_assign and not has_into:
                # Convert: SELECT p_var = expr, p_var2 = expr2 FROM table
                # To:      SELECT expr, expr2 INTO p_var, p_var2 FROM table
                full_stmt = _fix_escaped_select_assignment(full_stmt)
                result.append(full_stmt)
            elif not has_into and not is_insert_select:
                # Prefix with RETURN QUERY or PERFORM
                if return_type.startswith("SETOF"):
                    stmt_lines[0] = re.sub(r'^(\s*)SELECT\b', r'\1RETURN QUERY SELECT', stmt_lines[0], count=1, flags=re.IGNORECASE)
                else:
                    stmt_lines[0] = re.sub(r'^(\s*)SELECT\b', r'\1PERFORM', stmt_lines[0], count=1, flags=re.IGNORECASE)

                full_stmt = '\n'.join(stmt_lines)
                result.append(full_stmt)
            else:
                result.append(full_stmt)
        else:
            result.append(line)
        i += 1

    return '\n'.join(result)


def _fix_escaped_select_assignment(stmt: str) -> str:
    """
    Fix escaped assignment: SELECT p_var = expr, p_var2 = expr2 FROM table;
    Convert to:             SELECT expr, expr2 INTO p_var, p_var2 FROM table;
    Handles commas inside parentheses properly.
    """
    # Extract indentation
    indent_m = re.match(r'^(\s*)', stmt)
    indent = indent_m.group(1) if indent_m else '    '

    # Remove SELECT keyword and trailing semicolon
    core = re.sub(r'(?i)^\s*SELECT\s+', '', stmt).rstrip(';').strip()

    # Find top-level FROM
    from_pos = _find_top_level_keyword(core, 'FROM')
    if from_pos >= 0:
        assign_part = core[:from_pos].strip()
        from_clause = core[from_pos + 4:].strip()
    else:
        assign_part = core
        from_clause = None

    # Parse assignment pairs: p_var = expr, p_var2 = expr2
    pairs = _split_assignments(assign_part)
    if not pairs:
        return stmt  # Can't parse, return unchanged

    targets = []
    exprs = []
    for var_name, expr in pairs:
        targets.append(var_name)
        exprs.append(expr)

    if from_clause:
        return f"{indent}SELECT {', '.join(exprs)} INTO {', '.join(targets)} FROM {from_clause};"
    else:
        # No FROM - convert to simple assignments
        lines = []
        for var_name, expr in pairs:
            lines.append(f"{indent}{var_name} := {expr};")
        return '\n'.join(lines)


def _find_top_level_keyword(text: str, keyword: str) -> int:
    """Find position of a keyword at top level (not inside parentheses or quotes)"""
    depth = 0
    in_quote = False
    kw_len = len(keyword)
    kw_upper = keyword.upper()
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "'" and not in_quote:
            in_quote = True
        elif ch == "'" and in_quote:
            in_quote = False
        elif not in_quote:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif depth == 0 and text[i:i+kw_len].upper() == kw_upper:
                # Check word boundaries
                before_ok = (i == 0 or not text[i-1].isalnum() and text[i-1] != '_')
                after_ok = (i + kw_len >= len(text) or not text[i+kw_len].isalnum() and text[i+kw_len] != '_')
                if before_ok and after_ok:
                    return i
        i += 1
    return -1


def _split_assignments(text: str) -> list:
    """
    Split 'p_var = expr, p_var2 = expr2' into [(var, expr), ...].
    Respects parentheses nesting.
    """
    pairs = []
    pos = 0
    while pos < len(text):
        # Match p_var or v_var at current position
        var_m = re.match(r'\s*([pv]_\w+)\s*=\s*', text[pos:])
        if not var_m:
            break
        var_name = var_m.group(1)
        expr_start = pos + var_m.end()

        # Scan for next top-level comma followed by p_/v_ assignment
        depth = 0
        in_quote = False
        i = expr_start
        expr_end = len(text)
        while i < len(text):
            ch = text[i]
            if ch == "'" and not in_quote:
                in_quote = True
            elif ch == "'" and in_quote:
                in_quote = False
            elif not in_quote:
                if ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                elif depth == 0 and ch == ',':
                    # Check if next token is p_var = or v_var =
                    after = text[i+1:]
                    if re.match(r'\s*[pv]_\w+\s*=', after):
                        expr_end = i
                        break
            i += 1

        expr_val = text[expr_start:expr_end].strip()
        if expr_val:
            pairs.append((var_name, expr_val))
        pos = expr_end + 1 if expr_end < len(text) else len(text)

    return pairs


def _apply_final_fixes(sql: str) -> str:
    """Apply targeted fixes for known edge cases like boolean/integer mismatch"""
    # 0. Fix CAST(boolean AS smallint/integer) -> CASE WHEN bool THEN 1 ELSE 0 END
    # PG doesn't allow direct cast of boolean to numeric types
    def fix_bool_cast(m):
        expr = m.group(1).strip()
        type_str = m.group(2).strip().lower()
        return f"(CASE WHEN {expr} THEN 1 ELSE 0 END)::{type_str}"
    sql = re.sub(r'(?i)\bCAST\s*\(\s*(gender\b[^)]*?)\s+AS\s+(smallint|integer|int)\s*\)', fix_bool_cast, sql)

    # 0b. Fix hex literals: 0x[hex] -> decimal integer equivalent
    # T-SQL hex literals are used as integer values in numeric comparisons,
    # so convert to decimal integer instead of bytea to avoid type mismatches
    def fix_hex_literal(m):
        hex_val = m.group(1)
        try:
            int_val = int(hex_val, 16)
            return str(int_val)
        except ValueError:
            return m.group(0)  # keep original if parse fails
    sql = re.sub(r'\b0x([0-9A-Fa-f]+)\b', fix_hex_literal, sql)

    # 0c. Fix double concatenation operators: || || -> ||
    # Happens when + was converted to || and then the post-processor also added ||
    sql = re.sub(r'\|\|\s*\|\|', '||', sql)

    # 1. Boolean fields: gender, bit fields that were converted but still use 0/1 in logic
    # gender is boolean in PG
    sql = re.sub(r'(?i)\bgender\s*=\s*0\b', 'gender = false', sql)
    sql = re.sub(r'(?i)\bgender\s*=\s*1\b', 'gender = true', sql)
    sql = re.sub(r'(?i)\bgender\s*<>\s*0\b', 'gender = true', sql)
    sql = re.sub(r'(?i)\bgender\s*<>\s*1\b', 'gender = false', sql)

    # 1b. Fix gender = p_nGender where gender is boolean but p_nGender is integer
    # Convert to boolean expression: gender = (p_nGender != 0)
    sql = re.sub(r'(?i)\bgender\s*=\s*(p_\w+)\b', r'gender = (\1 != 0)', sql)
    
    # 2. Fix logfile_id, organization_id, notice_history_id which are integer but compared to varchar
    id_fields = ['logfile_id', 'organization_id', 'notice_history_id', 'account_id', 'user_id', 'player_id', 'char_id', 'item_id', 'guild_id']
    for field in id_fields:
        # column = '123' -> column = 123
        sql = re.sub(r'(?i)\b(' + field + r')\s*(=|<>)\s*\'(\d+)\'', r'\1 \2 \3', sql)
        # column = p_var -> column = p_var::integer (if we suspect p_var is varchar)
        # This is risky, but let's try for common ones
        # sql = re.sub(r'(?i)\b(' + field + r')\s*(=|<>)\s*(p_\w+)\b', r'\1 \2 \3::integer', sql)
    
    # 3. Handle character varying <> integer
    # sql = re.sub(r'(?i)\b(p_\w+)\s*(<>|=)\s*(\d+)\b', r'\1::integer \2 \3', sql)
    
    # 4. T-SQL SELECT alias = expr -> SELECT expr AS alias
    # Handles things like SELECT rnk = RANK() OVER(...)
    # Match at line start (standalone SELECT statements)
    def fix_select_alias(m):
        indent = m.group(1)
        alias = m.group(2)
        expr = m.group(3)
        return f"{indent}SELECT {expr} AS {alias}"

    sql = re.sub(r'(?im)^(\s*)SELECT\s+([a-zA-Z0-9_]+)\s*=\s*(RANK\(|ROW_NUMBER\(|DENSE_RANK\(|COUNT\(|SUM\(|MIN\(|MAX\(|AVG\(|CAST\(|COALESCE\(|CASE\b)', fix_select_alias, sql)

    # 4b. Also fix alias=expr within comma-separated SELECT lists (not at start)
    # Pattern: , alias = FUNC( -> , FUNC( AS alias
    def fix_inline_select_alias(m):
        sep = m.group(1)
        alias = m.group(2)
        expr = m.group(3)
        return f"{sep}{expr} AS {alias}"
    sql = re.sub(r'(,\s+)([a-zA-Z0-9_]+)\s*=\s*(RANK\(|ROW_NUMBER\(|DENSE_RANK\(|COUNT\(|SUM\(|MIN\(|MAX\(|AVG\(|CAST\(|COALESCE\(|CASE\b)', fix_inline_select_alias, sql)
    
    # 5. Fix binary() in SQL strings or expressions
    # T-SQL: master.fn_varbintohexstr(binary(@var))
    sql = re.sub(r'(?i)master\.fn_varbintohexstr\b', 'encode', sql)
    sql = re.sub(r'(?i)encode\s*\(\s*binary\s*\((.+?)\)\s*\)', r"encode(binary(\1), 'hex')", sql)

    # 6. Fix numeric(precision) or decimal(precision) without scale
    sql = re.sub(r'(?i)\b(numeric|decimal)\s*\(\s*(\d+)\s*\)', r'\1(\2, 0)', sql)

    # 7. Fix empty EXECUTE strings
    sql = re.sub(r'(?i)EXECUTE\s+\'\';', '-- EXECUTE empty string;', sql)
    
    # 8. Fix double AS in SELECT
    sql = re.sub(r'(?i)\bAS\s+AS\b', 'AS', sql)

    # 9. Fix double semicolons
    sql = re.sub(r';\s*;', ';', sql)

    # 10. Fix variable assignment with double colon
    sql = re.sub(r'(\w+)\s+::=\s+', r'\1 := ', sql)

    # 11. Fix T-SQL Join hints: INNER LOOP JOIN, LEFT HASH JOIN etc.
    sql = re.sub(r'(?i)\bINNER\s+(?:LOOP|HASH|MERGE)\s+JOIN\b', 'INNER JOIN', sql)
    sql = re.sub(r'(?i)\bLEFT\s+(?:LOOP|HASH|MERGE)\s+OUTER\s+JOIN\b', 'LEFT JOIN', sql)
    sql = re.sub(r'(?i)\bLEFT\s+(?:LOOP|HASH|MERGE)\s+JOIN\b', 'LEFT JOIN', sql)

    # 12. Fix sys.tables and sys.columns references
    sql = re.sub(r'(?i)\bsys\.tables\b', 'information_schema.tables', sql)
    sql = re.sub(r'(?i)\bsys\.columns\b', 'information_schema.columns', sql)
    sql = re.sub(r'(?i)\bsys\.all_columns\b', 'information_schema.columns', sql)
    sql = re.sub(r'(?i)\bsys\.schemas\b', 'information_schema.schemata', sql)
    sql = re.sub(r'(?i)\bsys\.objects\b', 'information_schema.tables', sql)

    # 13. Fix multiple LIMITs (bug in TOP conversion with UNION)
    # If we see LIMIT 1 LIMIT 1, keep only one
    sql = re.sub(r'(\s*LIMIT\s+\d+)(\s+LIMIT\s+\d+)+', r'\1', sql)

    # 14. Fix dynamic SQL SELECT INTO temp table
    # Pattern: v_sql := 'SELECT ... INTO temp_table ...'
    # Should be: v_sql := 'CREATE TABLE temp_table AS SELECT ...'
    def fix_dynamic_select_into(m):
        pre = m.group(1)
        select_part = m.group(2)
        temp_table = m.group(3)
        post = m.group(4)
        return f"{pre}CREATE TEMP TABLE {temp_table} AS {select_part} {post}"

    sql = re.sub(r'(?i)(v_sql\s*:=\s*\'\s*)SELECT\b(.*?)\bINTO\s+(\w+\$)\b(.*?)\'', fix_dynamic_select_into, sql)

    # 15. Fix mixed concatenation (+ and ||)
    # Often happens when strings were partially converted
    sql = re.sub(r'(\'\s*\|\|\s*v_\w+\s*)\+\s*(\')', r'\1|| \2', sql)
    sql = re.sub(r'(\'\s*)\+\s*(v_\w+\s*\|\|\s*\')', r'\1 || \2', sql)

    # 16. Fix UPDATE ... FROM self-join syntax for PG
    # Pattern: UPDATE table SET ... FROM table alias ... (alias must not be a SQL keyword)
    _SQL_KEYWORDS = r'(?:WHERE|SET|FROM|JOIN|ON|AND|OR|ORDER|GROUP|HAVING|INNER|LEFT|RIGHT|CROSS|LIMIT|INTO|VALUES|BEGIN|END|IF|ELSE|THEN|CASE|WHEN)'
    def fix_update_from_self(m):
        table = m.group(1)
        set_clause = m.group(2)
        alias = m.group(3)
        # Don't fix if alias is a SQL keyword (regex false match)
        if re.match(r'(?i)^' + _SQL_KEYWORDS + r'$', alias):
            return m.group(0)
        return f"UPDATE {table} AS {alias} SET {set_clause} FROM {table} AS {alias}"
    sql = re.sub(r'(?i)UPDATE\s+(\w+)\s+SET\s+(.+?)\s+FROM\s+\1\s+(?:AS\s+)?(\w+)', fix_update_from_self, sql)

    # 17. Fix residual convert(type, expr) calls not caught by convert_convert_balanced
    # e.g. convert(date, CURRENT_TIMESTAMP) -> CAST(CURRENT_TIMESTAMP AS date)
    def fix_residual_convert(m):
        type_str = m.group(1).strip()
        expr = m.group(2).strip()
        pg_type = convert_type(type_str)
        return f"CAST({expr} AS {pg_type})"
    sql = re.sub(r'(?i)\bconvert\s*\(\s*(\w+)\s*,\s*([^)]+)\)', fix_residual_convert, sql)

    # 18. Fix cross-database references: DBName.dbo.proc or DBName..proc -> proc
    sql = re.sub(r'(?i)\b(?:GlobalAccountDB|AionAccountDB|AionWorldLive|AionAccountCacheDB|LIVE_AionGM)\s*\.\s*(?:dbo\s*\.)?\s*', '', sql)
    # Also fix DBName(.proc pattern (broken by missing dot)
    sql = re.sub(r'(?i)\b(?:GlobalAccountDB|AionAccountDB|AionWorldLive|AionAccountCacheDB|LIVE_AionGM)\s*\(\s*\.', '', sql)

    # 19. Fix IF condition PRINT 'msg' -> IF condition THEN RAISE NOTICE
    def fix_if_print(m):
        indent = m.group(1)
        cond = m.group(2).strip()
        msg = m.group(3)
        return f"{indent}IF {cond} THEN\n{indent}    RAISE NOTICE '%', {msg};\n{indent}END IF;"
    sql = re.sub(r"(?im)^(\s*)IF\s+(.+?)\s+PRINT\s+('.*?')\s*(?:THEN)?", fix_if_print, sql)

    # 20. Fix "integer || integer" that might have been missed
    sql = re.sub(r'(\b[pv]_\w+)\s*\|\|\s*(\b[pv]_\w+)', r'\1::text || \2::text', sql)

    # 20b. Fix remaining v_var + v_var patterns (string concat that wasn't converted)
    # Only in lines with dynamic SQL context (:=, EXECUTE, RAISE)
    def _fix_remaining_plus(sql_text):
        lines = sql_text.split('\n')
        result = []
        for line in lines:
            if '+' in line and ('v_sql' in line or 'v_query' in line or 'v_txt' in line or
                                'v_str' in line or ':=' in line and ("||" in line or "'" in line)):
                # Convert v_var + v_var and v_var + 'string' patterns
                line = re.sub(r'([pv]_\w+)\s*\+\s*([pv]_\w+)', r'\1 || \2', line)
                line = re.sub(r"([pv]_\w+)\s*\+\s*'", r"\1 || '", line)
                line = re.sub(r"'\s*\+\s*([pv]_\w+)", r"' || \1", line)
            result.append(line)
        return '\n'.join(result)
    sql = _fix_remaining_plus(sql)

    # 20c. Fix varchar parameter = integer column comparisons
    # T-SQL allows implicit conversion; PG requires explicit cast
    # Add ::integer to p_ params when compared with known integer column patterns
    _INT_COLS = (r'(?:char_id|user_id|account_id|guild_id|item_id|world_id|server_id|'
                 r'zone_id|race|class|gender|lev|type|status|flag|warehouse|slot|'
                 r'instance_id|legion_id|abyss_id|rate_id|rank|score|count|amount|'
                 r'organization_id|logfile_id|notice_history_id|obj_id|npc_id|quest_id|'
                 r'mail_id|block_id|pet_id|house_id|owner_id|target_id|group_id)')
    # Pattern: column_name = p_param or column_name <> p_param (WHERE context)
    sql = re.sub(
        r'(?i)\b(' + _INT_COLS + r')\s*(=|<>|!=|<|>|<=|>=)\s*(p_\w+)\b(?!::)',
        r'\1 \2 \3::integer', sql
    )
    # Pattern: p_param = column_name (reverse order)
    sql = re.sub(
        r'(?i)\b(p_\w+)\b(?!::)\s*(=|<>|!=|<|>|<=|>=)\s*(' + _INT_COLS + r')\b',
        r'\1::integer \2 \3', sql
    )

    # 21. Fix CAST(CAST(... AS date) AS bytea) -> integer date representation
    # Originally T-SQL CONVERT(binary, CONVERT(date, ...)) which converts date to binary
    # In PG, use TO_CHAR to get YYYYMMDD integer instead of bytea
    def fix_date_to_bytea(m):
        inner_expr = m.group(1)
        return f"CAST(TO_CHAR(CAST({inner_expr} AS date), 'YYYYMMDD') AS integer)"
    sql = re.sub(r'(?i)\bCAST\s*\(\s*CAST\s*\(\s*(.+?)\s+AS\s+date\s*\)\s+AS\s+bytea\s*\)', fix_date_to_bytea, sql)

    # 22. Fix UPDATE table SET ... FROM table WHERE ... (duplicate table reference)
    # PG treats the table name as ambiguous when it appears in both UPDATE and FROM
    # Remove the FROM clause when it references the same table as UPDATE
    sql = re.sub(
        r'(?i)\bUPDATE\s+(\w+)\s+SET\s+(.*?)\s+FROM\s+\1\s+WHERE\b',
        lambda m: f"UPDATE {m.group(1)} SET {m.group(2)} WHERE",
        sql, flags=re.DOTALL
    )

    # 23. Fix SELECT TOP N inside dynamic SQL string literals
    # Handles both TOP N and TOP (N) forms inside string concatenation context
    # Strategy: find SELECT TOP patterns and move N to LIMIT at the end of the string segment
    def _fix_top_in_dynamic_sql(sql_text):
        """Convert SELECT TOP N patterns inside single-quoted string literals to LIMIT N"""
        # Pattern: SELECT TOP N or SELECT TOP (N) inside string literals
        # We process line by line to avoid cross-line regex issues
        lines = sql_text.split('\n')
        result = []
        for line in lines:
            # Only process lines that are likely dynamic SQL assignments
            if ('TOP' in line.upper() or 'top' in line.lower()) and ("'" in line):
                # Handle SELECT TOP (expr) - parenthesized form
                line = re.sub(
                    r"(?i)(SELECT\s+(?:DISTINCT\s+)?)TOP\s*\(\s*(\w+)\s*\)\s+",
                    r'\1',
                    line
                )
                # Handle SELECT TOP N - numeric form
                def replace_top_n(m):
                    prefix = m.group(1)
                    n = m.group(2)
                    # Store the LIMIT value - we'll append it
                    replace_top_n._pending_limit = n
                    return prefix
                replace_top_n._pending_limit = None
                new_line = re.sub(
                    r"(?i)(SELECT\s+(?:DISTINCT\s+)?)TOP\s+(\d+)\s+",
                    replace_top_n,
                    line
                )
                if replace_top_n._pending_limit is not None:
                    n = replace_top_n._pending_limit
                    # Find where to place LIMIT: before the closing quote of the string
                    # Look for the last ' on the line (or before concatenation operator)
                    # Simple heuristic: add LIMIT N before trailing ' or before ' ||
                    # Find the rightmost relevant quote
                    idx = new_line.rfind("'")
                    if idx > 0:
                        # Check if this is an escaped quote ''
                        while idx > 0 and idx < len(new_line) - 1 and new_line[idx+1] == "'":
                            idx = new_line.rfind("'", 0, idx)
                        if idx > 0:
                            new_line = new_line[:idx] + f" LIMIT {n}" + new_line[idx:]
                    line = new_line
            result.append(line)
        return '\n'.join(result)

    sql = _fix_top_in_dynamic_sql(sql)

    return sql


# --- Main Procedure Converter ---

def convert_procedure(name: str, tsql_source: str) -> ConversionResult:
    """Convert a single T-SQL stored procedure to PL/pgSQL function"""
    warnings = []
    confidence = Confidence.AUTO
    original = tsql_source

    # Normalize line endings
    tsql_source = tsql_source.replace('\r\n', '\n').replace('\r', '\n')

    # Extract procedure name, parameters, and body
    # The AS keyword that separates params from body is typically:
    # 1. On its own line: \nAS\n
    # 2. After the last param before BEGIN or SET or a DML
    # We need to distinguish it from @param AS type
    # Strategy: find the last AS that is NOT preceded by @word on the same line
    proc_match = re.search(
        r'(?i)CREATE\s+PROC(?:EDURE)?\s+(?:\[?dbo\]?\.)?\[?(\w+)\]?\s*(.*?)\bAS\b(?=\s*(?:\n|BEGIN\b|SET\b|SELECT\b|INSERT\b|UPDATE\b|DELETE\b|DECLARE\b|IF\b|RETURN\b|EXEC\b|PRINT\b|CREATE\b|WHILE\b|--|\r))(.*)',
        tsql_source,
        re.DOTALL
    )
    if not proc_match:
        # Fallback: try matching AS on its own line
        proc_match = re.search(
            r'(?i)CREATE\s+PROC(?:EDURE)?\s+(?:\[?dbo\]?\.)?\[?(\w+)\]?\s*(.*?)(?:^|\n)\s*AS\s*(?:\n|$)(.*)',
            tsql_source,
            re.DOTALL
        )
    if not proc_match:
        # Last fallback: original pattern
        proc_match = re.search(
            r'(?i)CREATE\s+PROC(?:EDURE)?\s+(?:\[?dbo\]?\.)?\[?(\w+)\]?\s*(.*?)\bAS\b(.*)',
            tsql_source,
            re.DOTALL
        )

    if not proc_match:
        return ConversionResult(
            name=name,
            confidence=Confidence.MANUAL,
            sql=f"-- TODO: MANUAL REVIEW NEEDED - Could not parse procedure\n/* Original T-SQL:\n{original}\n*/",
            warnings=["Could not parse CREATE PROCEDURE statement"],
            original_sql=original
        )

    extracted_name = proc_match.group(1)
    param_text = proc_match.group(2).strip()
    body_raw = proc_match.group(3).strip()

    # Strip outer parentheses from parameter block if present
    # T-SQL allows: CREATE PROC name (@p1 int, @p2 int) AS ...
    param_text_stripped = param_text.strip()
    if param_text_stripped.startswith('(') and ')' in param_text_stripped:
        # Find matching close paren
        depth = 0
        for ci, ch in enumerate(param_text_stripped):
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0:
                    param_text = param_text_stripped[1:ci].strip()
                    break

    # Clean up body - remove outer BEGIN...END if present
    body_stripped = body_raw.strip()
    # First, truncate at GO or SET ANSI_NULLS that appear after the procedure body
    body_stripped = re.split(r'(?m)^\s*GO\s*$', body_stripped)[0]
    # Remove trailing SET ANSI_NULLS, SET QUOTED_IDENTIFIER etc.
    body_stripped = re.sub(r'(?i)\s*SET\s+(?:ANSI_NULLS|QUOTED_IDENTIFIER)\s+(?:ON|OFF)\s*$', '', body_stripped)

    outer_begin = re.match(r'(?i)^\s*BEGIN\b(.*)', body_stripped, re.DOTALL)
    if outer_begin:
        inner = outer_begin.group(1).strip()
        # Find the LAST END at top level (not nested)
        # Walk backward to find the matching END for this BEGIN
        depth = 0
        last_end_pos = -1
        lines = inner.split('\n')
        pos = 0
        for line in lines:
            stripped_line = line.strip().lower()
            # Count BEGIN/END to find the outermost END
            if re.match(r'(?i)begin\b', stripped_line) and not re.match(r'(?i)begin\s+tran', stripped_line):
                depth += 1
            if re.match(r'(?i)end\s*;?\s*$', stripped_line):
                if depth > 0:
                    depth -= 1
                else:
                    last_end_pos = pos
            pos += len(line) + 1
        if last_end_pos >= 0:
            body_raw = inner[:last_end_pos].strip()
        else:
            # Fallback: find last END
            end_match = re.search(r'(?i)\bEND\s*;?\s*$', inner)
            if end_match:
                body_raw = inner[:end_match.start()].strip()
            else:
                body_raw = inner
    else:
        body_raw = body_stripped

    # Parse parameters
    params = parse_parameters(param_text)

    # Build param_map: lowercase name -> pg_name
    param_map = {}
    for p in params:
        var_name = p.name.lstrip("@").lower()
        param_map[var_name] = p.pg_name

    # Build function signature
    in_params = [p for p in params if not p.is_output]
    out_params = [p for p in params if p.is_output]

    # In PG, parameters with defaults must come after all non-default params.
    # Remove defaults from params that are followed by non-default params.
    last_no_default = -1
    for i, p in enumerate(in_params):
        if not p.default_value:
            last_no_default = i
    for i, p in enumerate(in_params):
        if i < last_no_default and p.default_value:
            p.default_value = None  # Remove invalid default

    param_defs = []
    for p in in_params:
        param_def = f"    {p.pg_name} {p.data_type}"
        if p.default_value:
            param_def += f" DEFAULT {p.default_value}"
        param_defs.append(param_def)
    for p in out_params:
        param_defs.append(f"    OUT {p.pg_name} {p.data_type}")

    param_block = ",\n".join(param_defs)

    # Determine return type
    has_return_value = bool(re.search(r'(?i)\bRETURN\s+(?!;)(?:@\w+|@@\w+|\d+|LASTVAL|SCOPE_IDENTITY|v_)', body_raw))
    has_return_int = bool(re.search(r'(?i)\bRETURN\s+-?\d+', body_raw))
    has_return_identity = bool(re.search(r'(?i)\bRETURN\s+@@(?:IDENTITY|ROWCOUNT)', body_raw))
    has_return_lastval = bool(re.search(r'(?i)\bRETURN\s+@@IDENTITY', body_raw))
    has_select_result = False

    # Check for result-set returning SELECTs using statement splitter
    # This handles multi-line SELECTs where FROM is on a different line
    _check_stmts = split_into_statements(body_raw)
    for _cstmt in _check_stmts:
        _cl = _cstmt.lower().strip()
        if not _cl.startswith('select'):
            continue
        # Check if this SELECT has INTO (variable assignment) before FROM
        _before_from = _cl.split('from')[0] if 'from' in _cl else _cl
        if 'into' in _before_from:
            continue
        # Check if this is a bare SELECT (not assignment via @var = expr)
        _select_part = _cstmt[:_cstmt.lower().find('from')] if 'from' in _cl else _cstmt
        if '@' not in _select_part and '=' not in _select_part:
            has_select_result = True
            break

    # Flag for OUT params with return values
    out_with_return = False
    if out_params:
        if has_return_int or has_return_value:
            # PG doesn't allow RETURN <value> with OUT params + RETURNS record.
            # Add a return_code OUT param and convert RETURN N to assignment.
            out_with_return = True
            out_params.append(ProcParam(
                name="@_return_code",
                pg_name="p_return_code",
                data_type="integer",
                is_output=True,
                default_value=None
            ))
            params.append(out_params[-1])
            param_defs.append(f"    OUT p_return_code integer")
            param_block = ",\n".join(param_defs)
            param_map['_return_code'] = 'p_return_code'
            return_type = "record"
        elif len(out_params) == 1:
            return_type = out_params[0].data_type
        else:
            return_type = "record"
    elif has_return_value and not has_return_int:
        # Function returns a variable/expression - determine type
        # If it returns @@IDENTITY or LASTVAL(), it's bigint
        if has_return_lastval or has_return_identity:
            return_type = "bigint"
        else:
            # Check RETURN @varname to see if we can figure out the type
            ret_m = re.search(r'(?i)\bRETURN\s+@(\w+)', body_raw)
            if ret_m:
                var = ret_m.group(1).lower()
                if var in param_map:
                    # Find param type
                    for p in params:
                        if p.name.lstrip('@').lower() == var:
                            return_type = p.data_type
                            break
                    else:
                        return_type = "integer"
                else:
                    return_type = "integer"
            else:
                return_type = "integer"
    elif has_return_int:
        return_type = "integer"
    elif has_select_result:
        return_type = "SETOF record"
    else:
        return_type = "void"

    # Convert body
    body_text, declare_lines, body_warnings, body_confidence = convert_statements(
        body_raw, param_map, name
    )

    # Post-convert: handle bare SELECT statements
    # A bare SELECT is one that does NOT have INTO and is a result-set query.
    # We always call this to ensure either RETURN QUERY or PERFORM is used.
    body_text = _add_return_query_to_bare_selects(body_text, return_type)
    warnings.extend(body_warnings)
    confidence = max_confidence(confidence, body_confidence)

    # Deduplicate declare_lines (fix duplicate v_rowcount)
    seen_declares = set()
    unique_declares = []
    for dl in declare_lines:
        # Extract variable name for dedup
        dm = re.match(r'\s+(\w+)\s+', dl)
        key = dm.group(1).lower() if dm else dl
        if key not in seen_declares:
            seen_declares.add(key)
            unique_declares.append(dl)
    declare_lines = unique_declares

    # Build final SQL
    func_name = name.lower()
    sql_parts = []
    sql_parts.append(f"CREATE OR REPLACE FUNCTION {func_name}(")
    if param_block:
        sql_parts.append(param_block)
    sql_parts.append(f") RETURNS {return_type}")
    sql_parts.append("LANGUAGE plpgsql")
    sql_parts.append("AS $$")

    if declare_lines:
        sql_parts.append("DECLARE")
        for dl in declare_lines:
            sql_parts.append(dl)

    sql_parts.append("BEGIN")
    if body_text.strip():
        sql_parts.append(body_text)
    sql_parts.append("END;")
    sql_parts.append("$$;")

    final_sql = '\n'.join(sql_parts)

    # Post-process: fix double semicolons
    final_sql = re.sub(r';;', ';', final_sql)

    # Post-process: fix if(condition); -> IF condition THEN
    final_sql = re.sub(r'(?i)\bif\s*\(([^)]+)\)\s*;', r'IF \1 THEN', final_sql)

    # Post-process: fix while(condition); -> WHILE condition LOOP
    final_sql = re.sub(r'(?im)^(\s+)while\s*\(([^)]+)\)\s*;', r'\1WHILE \2 LOOP', final_sql)

    # Post-process: fix "RETURN value THEN" -> should be "RETURN value;" (mismatched IF/RETURN)
    final_sql = re.sub(r'(?i)\bRETURN\s+(.+?)\s+THEN\b', r'RETURN \1;', final_sql)

    # Post-process: handle OUT params with return values
    if out_with_return:
        # Convert RETURN <integer>; to p_return_code := <integer>; RETURN;
        def replace_return_val(m):
            indent_str = m.group(1)
            val = m.group(2).strip()
            return f"{indent_str}p_return_code := {val};\n{indent_str}RETURN;"
        final_sql = re.sub(r'(?m)^(\s+)RETURN\s+(-?\d+);', replace_return_val, final_sql)
        # Convert RETURN LASTVAL(); and other expressions
        final_sql = re.sub(r'(?m)^(\s+)RETURN\s+(LASTVAL\(\)|v_\w+);',
                          lambda m: f"{m.group(1)}p_return_code := 0;\n{m.group(1)}{m.group(1).strip() or '    '}{m.group(0).strip().replace('RETURN', '-- RETURN_EXPR:')}",
                          final_sql)
        # Convert bare RETURN NULL; to RETURN;
        final_sql = re.sub(r'(?m)^(\s+)RETURN NULL;', r'\1RETURN;', final_sql)
        # Catch any remaining RETURN <expr>; not handled above
        # (e.g. RETURN p_SomeVar; or RETURN func_call();)
        # Exclude RETURN; (bare) and RETURN QUERY (result set)
        def replace_return_any_expr(m):
            indent_str = m.group(1)
            val = m.group(2).strip()
            if val.upper().startswith('QUERY'):
                return m.group(0)  # Don't touch RETURN QUERY
            return f"{indent_str}p_return_code := {val};\n{indent_str}RETURN;"
        final_sql = re.sub(r'(?m)^(\s+)RETURN\s+([^;]+);', replace_return_any_expr, final_sql)

    # Post-process: handle RETURN statements based on function signature
    if out_params:
        # Functions with OUT params: RETURN should be bare (no value)
        # PG auto-returns OUT param values on bare RETURN
        # Catch any RETURN <expr>; (not bare RETURN;, not RETURN QUERY)
        def strip_return_expr_for_out(m):
            indent_str = m.group(1)
            val = m.group(2).strip()
            if val.upper().startswith('QUERY'):
                return m.group(0)  # Don't touch RETURN QUERY
            return f"{indent_str}-- RETURN {val}; (stripped: function has OUT params)\n{indent_str}RETURN;"
        final_sql = re.sub(r'(?m)^(\s+)RETURN\s+([^;]+);', strip_return_expr_for_out, final_sql)
        final_sql = re.sub(r'(?m)^(\s+)RETURN NULL;\s*$', r'\1RETURN;', final_sql)
        final_sql = re.sub(r'(?m)^(\s+)RETURN NULL;(\s+--.*)$', r'\1RETURN;\2', final_sql)
    elif return_type == "SETOF record":
        # SETOF record functions: bare RETURN is correct (signals end of result set)
        # Convert RETURN NULL; back to bare RETURN;
        final_sql = re.sub(r'(?m)^(\s+)RETURN NULL;\s*$', r'\1RETURN;', final_sql)
        final_sql = re.sub(r'(?m)^(\s+)RETURN NULL;(\s+--.*)$', r'\1RETURN;\2', final_sql)
    elif return_type != "void":
        # Non-void scalar functions: bare RETURN needs a value
        final_sql = re.sub(r'(?m)^(\s+)RETURN;\s*$', r'\1RETURN NULL;', final_sql)
        final_sql = re.sub(r'(?m)^(\s+)RETURN;(\s+--.*)$', r'\1RETURN NULL;\2', final_sql)

    # Post-process: fix invalid "END ELSE BEGIN;" -> "ELSE"
    # This pattern occurs when END (closing IF's BEGIN block) + ELSE + BEGIN
    # are emitted sequentially. In PL/pgSQL, only ELSE is needed.
    final_sql = re.sub(r'(?im)^\s*END\s+ELSE\s+BEGIN\s*;\s*$', '    ELSE', final_sql)
    # Also fix variants: "END IF; ELSE" on separate lines should just be "ELSE"
    # Pattern: END IF;\n    ELSE where the END IF was wrongly emitted before ELSE
    final_sql = re.sub(r'(?m)^\s*END IF;\s*\n(\s*ELSE\b)', r'\1', final_sql)

    # Post-process: remove orphaned "-- END (no matching block);" lines
    final_sql = re.sub(r'\n\s*-- END \(no matching block\);\n', '\n', final_sql)

    # Post-process: fix TO_CHAR format strings inside dynamic SQL string literals
    # When TO_CHAR(expr, 'format') is inside a string concatenation context like
    # v_sql := '...TO_CHAR(col, 'YYYY-MM-DD')...', the inner quotes break the outer string.
    # Fix by doubling the inner quotes: TO_CHAR(col, ''YYYY-MM-DD'')
    def _fix_tochar_in_dynamic_sql(sql):
        """Fix TO_CHAR format strings that appear inside single-quoted string literals"""
        # Pattern: inside a string assignment (v_sql := '...' or || '...')
        # find TO_CHAR(anything, 'FORMAT') and double the FORMAT quotes
        # Strategy: find lines where v_sql assignment contains TO_CHAR
        lines = sql.split('\n')
        fixed = []
        for line in lines:
            if 'TO_CHAR(' in line and ":=" in line and "||" in line:
                # This line is likely a dynamic SQL assignment with TO_CHAR
                # Find TO_CHAR(expr, 'format') patterns and double the format quotes
                # But only when the TO_CHAR is INSIDE a string literal context
                # Heuristic: if ' appears before TO_CHAR and after the format closing '
                # then the format quotes need escaping
                result = []
                i = 0
                while i < len(line):
                    pos = line.find('TO_CHAR(', i)
                    if pos == -1:
                        result.append(line[i:])
                        break
                    result.append(line[i:pos])
                    # Find the matching closing paren for TO_CHAR(
                    start = pos + 8
                    depth = 1
                    j = start
                    while j < len(line) and depth > 0:
                        if line[j] == '(':
                            depth += 1
                        elif line[j] == ')':
                            depth -= 1
                        j += 1
                    tochar_content = line[start:j-1]
                    # Check if this TO_CHAR is inside a string context
                    # by checking if there's an odd number of ' before it (after :=)
                    assign_pos = line.find(':=')
                    if assign_pos >= 0 and assign_pos < pos:
                        before = line[assign_pos+2:pos]
                        quote_count = before.count("'") - before.count("''") * 2
                        if quote_count % 2 == 1:
                            # Inside a string literal - double the format quotes
                            # Find the format string: the last argument after comma
                            parts = split_args(tochar_content)
                            if len(parts) >= 2:
                                fmt = parts[-1].strip()
                                if fmt.startswith("'") and fmt.endswith("'"):
                                    # Double the quotes: 'fmt' -> ''fmt''
                                    new_fmt = "''" + fmt[1:-1] + "''"
                                    parts[-1] = " " + new_fmt
                                    tochar_content = ','.join(parts)
                    result.append(f'TO_CHAR({tochar_content})')
                    i = j
                fixed.append(''.join(result))
            else:
                fixed.append(line)
        return '\n'.join(fixed)

    final_sql = _fix_tochar_in_dynamic_sql(final_sql)

    # Post-process: apply final targeted fixes for boolean/integer/type mismatches
    final_sql = _apply_final_fixes(final_sql)

    # Post-process: strip any remaining lock hints (including inside dynamic SQL strings)
    _LOCK_HINTS_PP = r'NOLOCK|UPDLOCK|ROWLOCK|HOLDLOCK|TABLOCK|TABLOCKX|PAGLOCK|READPAST|READUNCOMMITTED|READCOMMITTED|REPEATABLEREAD|SERIALIZABLE|XLOCK'
    final_sql = re.sub(
        r'(?i)\s*WITH\s*\(\s*(?:' + _LOCK_HINTS_PP + r'|INDEX\s*(?:\([^)]*\)|=\w+))'
        r'(?:\s*,\s*(?:' + _LOCK_HINTS_PP + r'|INDEX\s*(?:\([^)]*\)|=\w+)))*\s*\)',
        '', final_sql
    )
    final_sql = re.sub(
        r'(?i)\(\s*(?:' + _LOCK_HINTS_PP + r')(?:\s*,\s*(?:' + _LOCK_HINTS_PP + r'))*\s*\)',
        '', final_sql
    )

    # Post-process: fix remaining string concatenation with + operator
    # Only convert in clear string context — avoid breaking arithmetic
    # Catch || + pattern (double conversion artifact)
    final_sql = re.sub(r'\|\|\s*\+\s*', '|| ', final_sql)
    # Catch string-literal-adjacent + that convert_expression might have missed
    final_sql = re.sub(r"'\s*\+\s*", "' || ", final_sql)
    final_sql = re.sub(r"\s*\+\s*'", " || '", final_sql)
    # Catch CAST(...AS varchar/text) + something patterns
    final_sql = re.sub(r'(\bCAST\([^)]+AS\s+(?:varchar|text|char)[^)]*\))\s*\+\s*', r'\1 || ', final_sql)
    # On lines that have || already (confirmed string context), convert remaining +
    def _fix_string_plus_line(line):
        """Convert remaining + to || only on lines with confirmed string concatenation"""
        if '+' not in line or '||' not in line:
            return line
        # Line already has || (confirmed string context), convert remaining +
        # But only between expressions, not in numeric contexts like >= <= != + -
        # Convert v_var + CAST/v_var + 'str' patterns
        line = re.sub(r'(\w+)\s*\+\s*(\bCAST\()', r'\1 || \2', line)
        line = re.sub(r'(\bCAST\([^)]+\))\s*\+\s*', r'\1 || ', line)
        return line
    final_sql = '\n'.join(_fix_string_plus_line(l) for l in final_sql.split('\n'))

    # Post-process: fix double-escaped single quotes in string literals
    # Pattern: ''text'' within COALESCE or function args should be 'text'
    # But be careful - PG uses '' to escape quotes inside strings
    # Only fix cases where it's clearly wrong: COALESCE(x, ''value'')
    # This is tricky - let's handle the specific pattern from TO_CHAR
    # e.g. COALESCE(u.create_date, ''1970-01-01'') should be COALESCE(u.create_date, '1970-01-01')
    # Actually the double quotes come from T-SQL string escaping within dynamic SQL
    # Let's not touch this as it may break valid escaping

    return ConversionResult(
        name=name,
        confidence=confidence,
        sql=final_sql,
        warnings=warnings,
        original_sql=original
    )


def process_database(json_path: str, output_path: str) -> dict:
    """Process all procedures from a database schema JSON file"""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    db_name = data.get('database', os.path.basename(json_path))
    procedures = data.get('procedures', {})

    if not procedures:
        print(f"  No procedures found in {db_name}")
        return {'total': 0, 'auto': 0, 'review': 0, 'manual': 0}

    results = []
    stats = {'total': 0, 'auto': 0, 'review': 0, 'manual': 0}

    for proc_name, tsql_source in procedures.items():
        stats['total'] += 1
        result = convert_procedure(proc_name, tsql_source)

        if result.confidence == Confidence.AUTO:
            stats['auto'] += 1
        elif result.confidence == Confidence.REVIEW:
            stats['review'] += 1
        else:
            stats['manual'] += 1

        results.append(result)

    # Write output SQL file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(f"-- ============================================================\n")
        f.write(f"-- PL/pgSQL Functions converted from {db_name}\n")
        f.write(f"-- Source: {os.path.basename(json_path)}\n")
        f.write(f"-- Total: {stats['total']} procedures\n")
        f.write(f"-- Auto-converted: {stats['auto']}\n")
        f.write(f"-- Needs review: {stats['review']}\n")
        f.write(f"-- Needs manual work: {stats['manual']}\n")
        f.write(f"-- ============================================================\n\n")

        f.write(f"-- Confidence Legend:\n")
        f.write(f"--   [AUTO]   - Fully automatic conversion\n")
        f.write(f"--   [REVIEW] - Likely correct, please verify\n")
        f.write(f"--   [MANUAL] - Needs human intervention\n\n")

        for result in results:
            badge = {
                Confidence.AUTO: "AUTO",
                Confidence.REVIEW: "REVIEW",
                Confidence.MANUAL: "MANUAL",
            }[result.confidence]

            tag = {
                Confidence.AUTO: "OK",
                Confidence.REVIEW: "WARN",
                Confidence.MANUAL: "ERR",
            }[result.confidence]

            f.write(f"-- [{tag}] [{badge}] {result.name}\n")

            if result.warnings:
                for w in result.warnings:
                    f.write(f"--   Warning: {w}\n")

            f.write(f"\n{result.sql}\n")

            # If manual review needed, include original T-SQL
            if result.confidence == Confidence.MANUAL:
                f.write(f"\n/* Original T-SQL for reference:\n")
                for line in result.original_sql.split('\n'):
                    f.write(f"   {line}\n")
                f.write(f"*/\n")

            f.write(f"\n-- --------------------------------------------------------\n\n")

    return stats


def main():
    """Main entry point"""
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    total_stats = {'total': 0, 'auto': 0, 'review': 0, 'manual': 0}
    start_time = time.time()

    print("=" * 60)
    print("T-SQL -> PL/pgSQL Stored Procedure Converter")
    print("=" * 60)
    print()

    for json_file, sql_file in SOURCE_FILES.items():
        json_path = os.path.join(SCRIPT_DIR, json_file)
        output_path = os.path.join(OUTPUT_DIR, sql_file)

        if not os.path.exists(json_path):
            print(f"  SKIP: {json_file} not found")
            continue

        print(f"Processing: {json_file}")
        stats = process_database(json_path, output_path)

        for k in total_stats:
            total_stats[k] += stats[k]

        print(f"  Total: {stats['total']}")
        print(f"  Auto:   {stats['auto']}")
        print(f"  Review: {stats['review']}")
        print(f"  Manual: {stats['manual']}")
        print(f"  Output: {sql_file}")
        print()

    elapsed = time.time() - start_time

    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total procedures:    {total_stats['total']}")
    print(f"Auto-converted:      {total_stats['auto']}")
    print(f"Needs review:        {total_stats['review']}")
    print(f"Needs manual work:   {total_stats['manual']}")
    print(f"Time elapsed:        {elapsed:.2f}s")
    print(f"Output directory:    {OUTPUT_DIR}")

    if total_stats['total'] > 0:
        auto_rate = total_stats['auto'] / total_stats['total'] * 100
        review_rate = total_stats['review'] / total_stats['total'] * 100
        manual_rate = total_stats['manual'] / total_stats['total'] * 100
        print(f"Auto rate:           {auto_rate:.1f}%")
        print(f"Review rate:         {review_rate:.1f}%")
        print(f"Manual rate:         {manual_rate:.1f}%")

    print()
    return total_stats


if __name__ == "__main__":
    stats = main()
    sys.exit(0 if stats['manual'] == 0 else 1)
