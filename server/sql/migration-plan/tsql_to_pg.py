#!/usr/bin/env python3
# tsql_to_pg.py — NCSoft T-SQL stored-procedure → PostgreSQL plpgsql converter.
#
# Round 4 Track B2 prototype. Goal: auto-port the easy 60-70% of the 1059
# AionWorldLive procedures and clearly mark TODO sections in the generated
# PG. Anything we can't port confidently is left as a `-- TODO:` comment so
# a human can finish.
#
# Strategy:
#   1. Strip T-SQL noise that doesn't translate (SET NOCOUNT, dbo., square
#      brackets, GO).
#   2. Parse header (CREATE PROC name + parameter list).
#   3. Translate parameters: @nFoo INT  ->  _n_foo INTEGER (PG snake_case-ish,
#      keeping a stable, predictable transform).
#   4. Translate body via regex passes for the well-known patterns:
#        @var               -> _var
#        IF @x = ...        -> IF _x = ... THEN ... END IF;
#        SELECT @x = expr   -> SELECT expr INTO _x;
#        PRINT 'msg'        -> RAISE NOTICE 'msg';
#        GETDATE()/GetUTCDate() -> NOW()/(NOW() AT TIME ZONE 'UTC')
#        TOP N expr         -> expr ... LIMIT N
#        ISNULL(a,b)        -> COALESCE(a,b)
#        BEGIN/END blocks   -> BEGIN ... END
#   5. Wrap in CREATE OR REPLACE FUNCTION ... RETURNS TABLE(...) | RETURNS VOID
#      | RETURNS INTEGER depending on the heuristic detection of the body.
#   6. If anything unrecognised remains (RAISERROR, sp_executesql, CURSOR,
#      OUTPUT params with complex use), drop a `-- TODO:` marker on that
#      line and keep going.
#
# We deliberately do NOT try to be 100% correct — sqlglot's transpile cannot
# handle CREATE PROCEDURE round-trips well; a conservative regex pipeline is
# more debuggable for game-data SPs which are mostly thin CRUD.
#
# Usage:
#   python tsql_to_pg.py <input.sql> [<output.sql>]
#   python tsql_to_pg.py --batch <input_dir> <output_dir>
#
# Exit codes:
#   0  ok (may still have TODOs, see stderr summary)
#   2  parse failure (kept original as comment, dumped TODO file)

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from typing import List, Optional

# ---------------------------------------------------------------------------
# Stage 1: strip T-SQL noise that has no PG equivalent.
# ---------------------------------------------------------------------------

# Patterns matched line-by-line and dropped entirely.
NOISE_LINE_RE = re.compile(
    r"^\s*(SET\s+NOCOUNT\s+(ON|OFF)|GO|USE\s+\w+|/\*+\s*개체.*?\*+/)\s*;?\s*$",
    re.IGNORECASE,
)

# Inline replacements applied to the whole body (post header strip).
INLINE_REPLACEMENTS = [
    # [dbo].[name] / dbo.name / [name] -> name
    (re.compile(r"\[dbo\]\.\[([A-Za-z_][\w]*)\]", re.IGNORECASE), r"\1"),
    (re.compile(r"\bdbo\.", re.IGNORECASE), ""),
    (re.compile(r"\[([A-Za-z_][\w]*)\]"), r"\1"),
    # date functions
    (re.compile(r"\bGetDate\s*\(\s*\)", re.IGNORECASE), "NOW()"),
    (re.compile(r"\bGetUTCDate\s*\(\s*\)", re.IGNORECASE), "(NOW() AT TIME ZONE 'UTC')"),
    # null helpers
    (re.compile(r"\bISNULL\s*\(", re.IGNORECASE), "COALESCE("),
    # PRINT -> RAISE NOTICE (rough)
    (re.compile(r"^\s*PRINT\s+(.+)$", re.IGNORECASE | re.MULTILINE),
     r"RAISE NOTICE '%', \1;"),
    # nvarchar(N) / varchar(N) keep, just strip the N to TEXT in param list (Stage 3)
    # convert SELECT TOP N -> trailing LIMIT N (handled as line transform Stage 4)
]


# ---------------------------------------------------------------------------
# Header parsing.
# ---------------------------------------------------------------------------

CREATE_HEADER_RE = re.compile(
    r"""
    \bCREATE\s+(?:OR\s+ALTER\s+)?(?:PROC(?:EDURE)?)\s+
    (?:\[?dbo\]?\.)?\[?(?P<name>[A-Za-z_][\w]*)\]?
    \s*(?P<params>.*?)
    \s*\bAS\b
    """,
    re.IGNORECASE | re.VERBOSE | re.DOTALL,
)

# Match a single param: @nFoo [type] [= default] [OUT|OUTPUT]
PARAM_RE = re.compile(
    r"""
    @(?P<name>\w+)\s+
    (?P<type>
        (?:n?varchar|nchar|char|varbinary|binary)\s*\(\s*(?:max|\d+)\s*\)
        | (?:datetime2?|smalldatetime|date|time|datetimeoffset)
        | (?:int|bigint|smallint|tinyint|bit|float|real|money|smallmoney)
        | (?:numeric|decimal)\s*\(\s*\d+(?:\s*,\s*\d+)?\s*\)
        | (?:numeric|decimal)
        | (?:uniqueidentifier|sysname|text|ntext|image|xml)
    )
    (?:\s*=\s*(?P<default>[^,]+?))?
    (?P<output>\s+(?:OUT|OUTPUT))?
    """,
    re.IGNORECASE | re.VERBOSE,
)


@dataclass
class Param:
    name: str        # without @, lowercased
    pg_name: str     # _name
    pg_type: str
    is_output: bool = False
    default: Optional[str] = None


@dataclass
class Conversion:
    name: str
    params: List[Param] = field(default_factory=list)
    body: str = ""
    todos: List[str] = field(default_factory=list)
    parsed: bool = False
    raw: str = ""


def _camel_to_snake(s: str) -> str:
    # Hungarian-ish prefixes: nFoo / strFoo / bFoo / dtFoo -> drop prefix when 1-2 lowercase chars
    s2 = re.sub(r"^[a-z]{1,3}(?=[A-Z])", "", s)
    s3 = re.sub(r"(?<!^)(?=[A-Z])", "_", s2).lower()
    return s3 or s.lower()


def tsql_type_to_pg(t: str) -> str:
    tl = t.lower().replace(" ", "")
    if tl.startswith(("nvarchar", "varchar", "nchar", "char", "ntext", "text", "sysname", "xml")):
        return "TEXT"
    if tl.startswith(("varbinary", "binary", "image")):
        return "BYTEA"
    if tl in ("int", "smallint", "tinyint"):
        return "INTEGER"
    if tl == "bigint":
        return "BIGINT"
    if tl == "bit":
        return "BOOLEAN"
    if tl in ("float", "real"):
        return "DOUBLE PRECISION"
    if tl in ("money", "smallmoney"):
        return "NUMERIC(19,4)"
    if tl.startswith(("numeric", "decimal")):
        # keep precision/scale if present
        m = re.match(r"(?:numeric|decimal)\s*\((\d+)(?:,(\d+))?\)", tl)
        if m:
            return f"NUMERIC({m.group(1)}{(',' + m.group(2)) if m.group(2) else ''})"
        return "NUMERIC"
    if tl.startswith("datetime") or tl in ("smalldatetime",):
        return "TIMESTAMPTZ"
    if tl == "date":
        return "DATE"
    if tl == "time":
        return "TIME"
    if tl == "uniqueidentifier":
        return "UUID"
    return "TEXT  -- TODO: unmapped type " + t


def parse_header(src: str) -> tuple[Optional[str], List[Param], str]:
    m = CREATE_HEADER_RE.search(src)
    if not m:
        return None, [], src
    name = m.group("name")
    params_blob = m.group("params") or ""
    params: List[Param] = []
    for pm in PARAM_RE.finditer(params_blob):
        raw_name = pm.group("name")
        params.append(Param(
            name=raw_name.lower(),
            pg_name="_" + _camel_to_snake(raw_name),
            pg_type=tsql_type_to_pg(pm.group("type")),
            is_output=bool(pm.group("output")),
            default=(pm.group("default") or "").strip() or None,
        ))
    body = src[m.end():]
    return name, params, body


# ---------------------------------------------------------------------------
# Body transformation.
# ---------------------------------------------------------------------------

def transform_body(body: str, params: List[Param], todos: List[str]) -> str:
    """Apply the mechanical regex passes."""
    # 1. drop noise lines
    body = "\n".join(
        line for line in body.splitlines() if not NOISE_LINE_RE.match(line)
    )

    # 2. inline replacements
    for pat, repl in INLINE_REPLACEMENTS:
        body = pat.sub(repl, body)

    # 3. translate @vars → _vars (params first, then any local @vars become _local)
    var_map = {p.name: p.pg_name for p in params}

    def at_to_underscore(m: re.Match) -> str:
        v = m.group(1)
        return var_map.get(v.lower(), "_" + _camel_to_snake(v))

    body = re.sub(r"@(\w+)", at_to_underscore, body)

    # 4. SELECT TOP N <cols> FROM ... -> SELECT <cols> FROM ... LIMIT N
    def top_to_limit(m: re.Match) -> str:
        n = m.group(1)
        rest = m.group(2)
        # if there is already an ORDER BY or end-of-statement, append LIMIT
        return f"SELECT {rest} /* LIMIT {n} appended */ LIMIT {n}"
    body = re.sub(r"SELECT\s+TOP\s+(\d+)\s+(.+?)(?=;|$)", top_to_limit,
                  body, flags=re.IGNORECASE | re.DOTALL)

    # 5. SELECT @x = expr FROM ... -> SELECT expr INTO _x FROM ...
    def select_assign(m: re.Match) -> str:
        target = m.group(1)
        expr = m.group(2)
        rest = m.group(3) or ""
        return f"SELECT {expr.strip()} INTO {target}{rest}"
    body = re.sub(
        r"SELECT\s+(_\w+)\s*=\s*(.+?)(\s+FROM\b.+?)?(?=;|$)",
        select_assign, body, flags=re.IGNORECASE | re.DOTALL,
    )

    # 6. SET @x = expr  -> _x := expr;
    body = re.sub(r"\bSET\s+(_\w+)\s*=\s*", r"\1 := ", body, flags=re.IGNORECASE)

    # 7. DELETE <table> WHERE ...  -> DELETE FROM <table> WHERE ...
    body = re.sub(r"\bDELETE\s+(?!FROM\b)(\w+)\b", r"DELETE FROM \1", body,
                  flags=re.IGNORECASE)

    # 8. RETURN <expr>  -> RETURN <expr>;  (kept but flagged if returns scalar)
    # leave as-is; CREATE FUNCTION wrapper deals with return type.

    # 9. flag unconvertible constructs
    for kw in ("RAISERROR", "sp_executesql", "CURSOR", "FETCH", "OPEN ", "CLOSE ",
               "DEALLOCATE", "WAITFOR", "OUTPUT INSERTED", "MERGE ", "TRY ", "CATCH "):
        if re.search(r"\b" + re.escape(kw) + r"\b", body, re.IGNORECASE):
            todos.append(f"unsupported T-SQL construct: {kw.strip()}")

    # 10. mark explicit TODOs as comments
    if todos:
        flag_block = "\n".join(f"-- TODO: {t}" for t in todos)
        body = flag_block + "\n" + body

    return body


# ---------------------------------------------------------------------------
# Return-type heuristic.
# ---------------------------------------------------------------------------

def detect_return(body: str) -> str:
    """Return the PG `RETURNS ...` clause."""
    has_select = re.search(r"\bSELECT\b(?!.*\bINTO\b)", body, re.IGNORECASE | re.DOTALL)
    has_explicit_return = re.search(r"\bRETURN\s+\w", body, re.IGNORECASE)
    if has_explicit_return and not has_select:
        return "RETURNS INTEGER"
    if has_select:
        # we can't reliably infer the column list; force caller to refine
        return "RETURNS SETOF RECORD  -- TODO: replace with explicit RETURNS TABLE(col TYPE, ...)"
    return "RETURNS VOID"


# ---------------------------------------------------------------------------
# Top-level conversion.
# ---------------------------------------------------------------------------

def convert(src: str) -> Conversion:
    todos: List[str] = []
    raw = src

    name, params, body = parse_header(src)
    if name is None:
        return Conversion(name="?", parsed=False, raw=raw,
                          todos=["could not locate CREATE PROCEDURE header"])

    body = transform_body(body, params, todos)
    return Conversion(name=name, params=params, body=body, todos=todos,
                      parsed=True, raw=raw)


def render(conv: Conversion, source_path: str) -> str:
    if not conv.parsed:
        msg = "; ".join(conv.todos) or "unknown parse failure"
        return (f"-- AUTO-PORT FAILED for {os.path.basename(source_path)}: {msg}\n"
                f"-- Original T-SQL preserved below as a comment block.\n"
                + "\n".join("-- " + ln for ln in conv.raw.splitlines())
                + "\n")

    pg_name = conv.name.lower()
    param_list = ", ".join(f"{p.pg_name} {p.pg_type}" for p in conv.params)
    return_clause = detect_return(conv.body)

    header = (
        f"-- Auto-ported from NCSoft T-SQL by tsql_to_pg.py.\n"
        f"-- Source file: {os.path.basename(source_path)}\n"
        f"-- Review TODOs before deploying.\n"
        f"\n"
        f"-- +goose Up\n"
        f"-- +goose StatementBegin\n"
        f"CREATE OR REPLACE FUNCTION {pg_name}({param_list})\n"
        f"{return_clause}\n"
        f"LANGUAGE plpgsql AS $$\n"
        f"BEGIN\n"
    )
    body = conv.body.strip()
    # ensure each statement ends with semicolon — best-effort
    if body and not body.rstrip().endswith(";"):
        body += ";"
    footer = (
        f"\nEND;\n"
        f"$$;\n"
        f"-- +goose StatementEnd\n"
        f"\n"
        f"-- +goose Down\n"
        f"-- +goose StatementBegin\n"
        f"DROP FUNCTION IF EXISTS {pg_name};\n"
        f"-- +goose StatementEnd\n"
    )
    return header + body + footer


# ---------------------------------------------------------------------------
# CLI.
# ---------------------------------------------------------------------------

def _convert_file(in_path: str, out_path: Optional[str]) -> Conversion:
    with open(in_path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()
    conv = convert(src)
    rendered = render(conv, in_path)
    if out_path:
        os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(rendered)
    else:
        sys.stdout.write(rendered)
    return conv


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description="NCSoft T-SQL SP -> PG converter")
    ap.add_argument("--batch", action="store_true",
                    help="Treat input as a directory and emit per-file PG SQL.")
    ap.add_argument("input")
    ap.add_argument("output", nargs="?")
    args = ap.parse_args(argv)

    if args.batch:
        if not args.output:
            ap.error("--batch requires <output_dir>")
        ok = todo = fail = 0
        for fn in sorted(os.listdir(args.input)):
            if not fn.lower().endswith(".sql"):
                continue
            in_p = os.path.join(args.input, fn)
            out_p = os.path.join(args.output, fn.lower())
            conv = _convert_file(in_p, out_p)
            if not conv.parsed:
                fail += 1
            elif conv.todos:
                todo += 1
            else:
                ok += 1
        sys.stderr.write(
            f"[tsql_to_pg] batch done: clean={ok} with_todos={todo} failed={fail}\n"
        )
        return 0 if fail == 0 else 2

    conv = _convert_file(args.input, args.output)
    if not conv.parsed:
        return 2
    if conv.todos:
        sys.stderr.write(f"[tsql_to_pg] {conv.name}: {len(conv.todos)} TODO(s)\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
