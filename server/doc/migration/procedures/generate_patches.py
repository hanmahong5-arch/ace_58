#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Generate PL/pgSQL patches for failing aion_world_live functions.
"""

import re
import json
import os
import sys

sys.stdout.reconfigure(errors='replace')

BASE = os.path.dirname(os.path.abspath(__file__))
PATCHES_DIR = os.path.join(BASE, 'patches')
os.makedirs(PATCHES_DIR, exist_ok=True)

# Load all data
with open(os.path.join(BASE, 'fix_list.json'), 'r', encoding='utf-8') as f:
    fix_data = json.load(f)
awl = {x['func']: x for x in fix_data if x['db'] == 'aion_world_live'}

with open(os.path.join(BASE, 'aion_world_live_procedures.sql'), 'r', encoding='utf-8') as f:
    content = f.read()
matches = list(re.finditer(r'CREATE OR REPLACE FUNCTION\s+(\w+)', content, re.IGNORECASE))
gen_funcs = {}
for i, m in enumerate(matches):
    name = m.group(1).lower()
    start = m.start()
    end = matches[i+1].start() if i+1 < len(matches) else len(content)
    body = content[start:end].rstrip()
    lines = body.split('\n')
    while lines and (lines[-1].strip().startswith('--') or lines[-1].strip() == ''):
        lines.pop()
    gen_funcs[name] = '\n'.join(lines)

with open(os.path.join(BASE, '..', 'AionWorldLive_schema.json'), 'r', encoding='utf-8') as f:
    schema = json.load(f)
procs_map = {}
for k, v in schema['procedures'].items():
    procs_map[k.lower()] = v


def write_patch(func_name, sql_content):
    path = os.path.join(PATCHES_DIR, f'{func_name}.sql')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(f'-- database: aion_world_live\n')
        f.write(sql_content.rstrip())
        f.write('\n')


def fix_string_concat(text):
    """Replace + with || for string concatenation in PL/pgSQL assignments."""
    # Fix v_var := v_var + v_var2
    text = re.sub(r"(v_\w+)\s*:=\s*(v_\w+)\s*\+\s*(v_\w+)", r"\1 := \2 || \3", text)
    # Fix more general cases: var + var in assignment
    lines = text.split('\n')
    result = []
    for line in lines:
        # Only fix lines that are PL/pgSQL assignments or EXECUTE
        if ':=' in line and '+' in line:
            # Replace + between identifiers/strings with ||
            # But be careful not to replace arithmetic +
            line = re.sub(r"(v_\w+)\s*\+\s*(v_\w+)", r"\1 || \2", line)
            line = re.sub(r"(v_\w+)\s*\+\s*'", r"\1 || '", line)
            line = re.sub(r"'\s*\+\s*(v_\w+)", r"' || \1", line)
        result.append(line)
    return '\n'.join(result)


def fix_select_top_in_dynamic(text):
    """Convert SELECT TOP N to SELECT ... LIMIT N in dynamic SQL strings."""
    # In dynamic SQL (string literals), convert 'select top N ...' to 'select ... limit N'
    # This is complex; for now just flag it
    return text


def fix_varchar_to_int_params(gen_sql, param_names_to_fix=None):
    """Change varchar parameters to integer where they should be integer."""
    if param_names_to_fix is None:
        # Auto-detect: find all varchar params that are compared to integer columns
        param_names_to_fix = []
        m = re.search(r'CREATE OR REPLACE FUNCTION \w+\((.*?)\)\s*RETURNS', gen_sql, re.DOTALL)
        if m:
            params_str = m.group(1)
            for pm in re.finditer(r'(p_\w+)\s+varchar\(\d+\)', params_str):
                pname = pm.group(1)
                # Check if this param is cast to integer anywhere
                if f'{pname}::integer' in gen_sql or f"= {pname}" in gen_sql:
                    param_names_to_fix.append(pname)

    for pname in param_names_to_fix:
        # Change param type from varchar(N) to integer
        gen_sql = re.sub(
            rf'({pname})\s+varchar\(\d+\)',
            rf'\1 integer',
            gen_sql
        )
        # Remove unnecessary ::integer casts
        gen_sql = gen_sql.replace(f'{pname}::integer', pname)

    return gen_sql


patched_count = 0
skipped_count = 0


def patch(fn, sql):
    global patched_count
    write_patch(fn, sql)
    patched_count += 1
    print(f'  PATCHED: {fn}')


# Process each function
for fn, item in awl.items():
    err = item['error']
    gen = gen_funcs.get(fn, '')
    tsql = procs_map.get(fn, '')

    if not gen and fn != 'convert':
        skipped_count += 1
        continue

    # Already patched check
    if os.path.exists(os.path.join(PATCHES_DIR, f'{fn}.sql')):
        continue

    # Determine error category
    is_varchar_eq_int = ('integer = character varying' in err or
                         'smallint = character varying' in err or
                         'character varying <> integer' in err or
                         'smallint = text' in err)
    is_string_concat = 'varying + character varying' in err
    is_bool_int = ('boolean' in err and 'integer' in err)
    is_missing_table = False  # will check per function
    is_delete_missing_from = 'DELETE WHERE' in gen or ('DELETE WHERE' in err)
    is_if_set = 'IF' in err and 'SET' in err and 'THEN' in err

    # ================================================================
    # Handle each function
    # ================================================================

    # --- Simple type mismatch: varchar param should be integer ---
    if is_varchar_eq_int:
        fixed = fix_varchar_to_int_params(gen)
        # Also check for specific issues per function
        if fn == 'gm_userchangelogda_srchbycharid':
            # change_type = '' || p_change_type -> change_type = p_change_type::smallint
            fixed = fix_varchar_to_int_params(gen)
            fixed = fixed.replace("change_type='' || p_change_type", "change_type=p_change_type")
        if fn == 'gm_houseda_srchallhouselist':
            # p_obj_id != 0 should compare varchar to string '0'
            # Actually need to cast or change param type
            fixed = fix_varchar_to_int_params(gen, ['p_char_id'])
            # Fix specific comparisons
            fixed = fixed.replace("p_obj_id != 0", "p_obj_id != '0'")
            fixed = fixed.replace("p_house_id != 0", "p_house_id != '0'")
            fixed = fixed.replace("p_address != 0", "p_address != '0'")
        if fn == 'gm_guildda_srchguildbyid':
            # COALESCE(u.user_id, 0) - user_id is varchar, 0 is int
            fixed = fixed.replace("COALESCE(u.user_id, 0)", "COALESCE(u.user_id, '0')")
        if fn == 'gm_useritemda_srchcountbynameidandcreatedateto':
            # timestamp <= character varying
            fixed = fixed.replace("create_date <= p_create_date_to", "create_date <= p_create_date_to::timestamp")
        patch(fn, fixed)
        continue

    # --- String concatenation + -> || ---
    if is_string_concat:
        fixed = fix_string_concat(gen)
        patch(fn, fixed)
        continue

    # --- Boolean/integer mismatch ---
    if is_bool_int and 'gender' in err:
        # gender column is boolean but we're inserting integer
        fixed = gen.replace('p_nGender,', 'p_nGender::boolean,')
        fixed = fixed.replace('p_nGender )', 'p_nGender::boolean )')
        # For putchar functions
        if 'p_nGender' in fixed:
            fixed = fixed.replace('p_nGender,', '(p_nGender != 0),')
        patch(fn, fixed)
        continue

    if fn == 'gm_userdatadao_updatecustomdata':
        # gender = (p_gender != 0) but boolean <> integer comparison
        fixed = gen.replace("(p_gender != 0)", "(p_gender::integer != 0)")
        patch(fn, fixed)
        continue

print(f'\nTotal: patched={patched_count}, skipped={skipped_count}')
print(f'Remaining: {len(awl) - patched_count - skipped_count}')
