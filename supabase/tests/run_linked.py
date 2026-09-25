#!/usr/bin/env python3
# path: supabase/tests/run_linked.py
"""Run the pgTAP suite against the LINKED Supabase project without saving anything.

Why this exists
    This workstation cannot run `supabase start` (no Docker), so there is no local
    database, and `supabase test db --linked` still needs Docker for pg_prove. This
    runs the suite as plain SQL through `supabase db query --linked` instead.
    Procedure and rationale: Ledger §24.7.

How it guarantees nothing is saved
    * The suite's own `begin;` / `rollback;` lines are removed and the whole run is
      wrapped in ONE transaction that ends by raising an exception. The exception
      aborts the transaction, so every fixture row rolls back. Its message is also
      how the TAP output gets out: the Management API returns a failed batch's
      error, but not the results of the statements before it.
    * A suite containing any other transaction control (commit, rollback, begin,
      end, abort, start/prepare transaction) is REFUSED before anything is sent. A
      mid-file commit or rollback would end the transaction early and let every
      later statement save. Keywords inside function bodies, strings and comments
      are ignored, so `do $$ begin ... end $$` is fine.
    * Row counts of every public table and auth.users, and whether the pgtap
      extension exists, are compared before and after the run.

What a pass here proves, and what it cannot
    It proves the policies and the assertions against real Supabase. It does NOT
    prove a fresh build: the hosted project carries platform default privileges and
    the full auth schema, and CI's Postgres-only stack has neither. That is how
    Ledger §24.6 passed 35/35 here while failing in CI. Iterate here; CI is the
    verdict.

Usage (from anywhere; the repository root is found from this file's location)
    python supabase/tests/run_linked.py                   # every supabase/tests/*.sql
    python supabase/tests/run_linked.py path/to/test.sql  # specific files

    Set SUPABASE_BIN if `supabase` is not on PATH.

Exit codes
    0  every assertion passed
    1  one or more assertions failed
    2  the suite errored before producing TAP output (the error is printed)
    3  refused (unsafe transaction control), or the database changed

Limitations
    Assertions must be written as `select <pgtap_function>(...)` at the start of a
    line, as pgTAP suites conventionally are. xUnit-style `runtests()` suites are
    not supported. Output from an unrecognised function is reported as a gap in the
    test numbering rather than lost silently.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TESTS_DIR = REPO / "supabase" / "tests"

# pgTAP functions that return TAP text. Each call to one of these at the start of a
# line is redirected into the capture table. Functions that return sets of booleans
# (no_plan, todo, todo_start, todo_end) are deliberately absent.
TAP_FUNCTIONS = (
    "plan", "finish", "diag", "skip", "pass", "fail",
    "ok", "is", "isnt", "matches", "imatches", "doesnt_match", "doesnt_imatch",
    "alike", "ialike", "unalike", "unialike", "cmp_ok", "isa_ok",
    "throws_ok", "throws_like", "throws_ilike", "throws_matching", "throws_imatching",
    "lives_ok", "performs_ok", "performs_within",
    "results_eq", "results_ne", "set_eq", "set_ne", "set_has", "set_hasnt",
    "bag_eq", "bag_ne", "bag_has", "bag_hasnt", "is_empty", "isnt_empty", "row_eq",
    "has_table", "hasnt_table", "has_view", "hasnt_view", "has_column", "hasnt_column",
    "col_type_is", "col_not_null", "col_is_null", "col_has_default", "col_default_is",
    "col_is_pk", "col_is_fk", "has_pk", "has_fk", "fk_ok",
    "has_function", "hasnt_function", "function_returns", "has_index", "has_trigger",
    "has_extension", "has_schema", "has_role", "has_type", "has_enum", "enum_has_labels",
    "tables_are", "columns_are", "functions_are", "is_member_of",
    "policies_are", "policy_cmd_is", "policy_roles_are",
    "table_privs_are", "schema_privs_are", "function_privs_are",
    "is_superuser", "isnt_superuser",
)

WRAP_RE = re.compile(
    r"^(\s*)select\s+(?:\*\s+from\s+)?(?:" + "|".join(TAP_FUNCTIONS) + r")\s*\(",
    re.IGNORECASE,
)
OWN_TXN_LINE_RE = re.compile(r"^\s*(begin|rollback)\s*;\s*$", re.IGNORECASE)
DOLLAR_TAG_RE = re.compile(r"\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$")
TAP_LINE_RE = re.compile(r"^(not ok|ok) (\d+)\b")
PLAN_RE = re.compile(r"^1\.\.(\d+)$")

BATCH_HEAD = """begin;
create extension if not exists pgtap with schema extensions;
create temp table _tap(n bigserial primary key, line text);
-- The assertions run after `set local role authenticated`; they must still be
-- able to write their results here.
grant all on table _tap to public;
grant all on sequence _tap_n_seq to public;
"""

# Always the last statement. The exception aborts the transaction (nothing is
# saved) and its message carries the collected TAP output back to the caller.
BATCH_TAIL = """
reset role;
do $tapout$ begin
  raise exception using message =
    E'TAPOUT\\n' || coalesce((select string_agg(line, E'\\n' order by n) from _tap), '');
end $tapout$;
"""

SNAPSHOT_SQL = """
select t.table_schema || '.' || t.table_name as item,
       (xpath('/row/c/text()',
              query_to_xml(format('select count(*) as c from %I.%I',
                                  t.table_schema, t.table_name),
                           false, true, '')))[1]::text::bigint as n
  from information_schema.tables t
 where t.table_type = 'BASE TABLE'
   and (t.table_schema = 'public' or (t.table_schema = 'auth' and t.table_name = 'users'))
union all
select 'extension:pgtap', count(*) from pg_extension where extname = 'pgtap'
order by 1;
"""


class SuiteError(Exception):
    """The database rejected the batch before the TAP output was produced."""


# --------------------------------------------------------------------------- #
# SQL masking — find statement-level code without being fooled by quoting
# --------------------------------------------------------------------------- #
def mask_quoted(sql: str) -> str:
    """Blank out comments, string literals and dollar-quoted bodies.

    The result has the same length and the same line breaks as the input, so a
    line in the mask lines up with the same line in the original. Keyword scans
    run on the mask; edits are applied to the original.
    """
    out = list(sql)
    i, n = 0, len(sql)

    def blank(start: int, end: int) -> None:
        for k in range(start, min(end, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        if sql.startswith("--", i):
            end = sql.find("\n", i)
            end = n if end == -1 else end
            blank(i, end)
            i = end
        elif sql.startswith("/*", i):
            end = sql.find("*/", i + 2)
            end = n if end == -1 else end + 2
            blank(i, end)
            i = end
        elif sql[i] == "'":
            escaped = i > 0 and sql[i - 1] in "eE"   # E'...' allows backslash escapes
            j = i + 1
            while j < n:
                if escaped and sql[j] == "\\":
                    j += 2
                    continue
                if sql[j] == "'":
                    if j + 1 < n and sql[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            blank(i, j + 1)
            i = j + 1
        else:
            m = DOLLAR_TAG_RE.match(sql, i)
            if m:
                tag = m.group(0)
                end = sql.find(tag, m.end())
                end = n if end == -1 else end + len(tag)
                blank(i, end)
                i = end
            else:
                i += 1
    return "".join(out)


def unsafe_transaction_control(masked: str) -> list[str]:
    """Statements that would end the wrapping transaction early."""
    found = []
    for stmt in masked.split(";"):
        s = " ".join(stmt.split())
        if not s:
            continue
        if re.match(r"(commit|end|abort|begin|start\s+transaction|prepare\s+transaction)\b", s, re.I):
            found.append(s[:60])
        elif re.match(r"rollback\b", s, re.I) and not re.match(
                r"rollback\s+(?:work\s+|transaction\s+)?to\b", s, re.I):
            found.append(s[:60])
    return found


def build_batch(suite: str) -> tuple[str, int | None]:
    """Return the rollback-guaranteed batch and the suite's planned test count."""
    masked_lines = mask_quoted(suite).split("\n")
    lines = suite.split("\n")

    kept_lines, kept_masked = [], []
    for line, masked in zip(lines, masked_lines):
        if OWN_TXN_LINE_RE.match(masked):
            continue                       # the suite's own begin/rollback
        m = WRAP_RE.match(masked)
        if m:
            line = f"{m.group(1)}insert into _tap(line) {line.lstrip()}"
        kept_lines.append(line)
        kept_masked.append(masked)

    unsafe = unsafe_transaction_control("\n".join(kept_masked))
    if unsafe:
        raise PermissionError(
            "refusing to run: the suite contains transaction control that would end the "
            "wrapping transaction early and let later statements save:\n  "
            + "\n  ".join(unsafe))

    plan = re.search(r"\bplan\s*\(\s*(\d+)\s*\)", "\n".join(kept_masked), re.I)
    return BATCH_HEAD + "\n".join(kept_lines) + BATCH_TAIL, int(plan.group(1)) if plan else None


# --------------------------------------------------------------------------- #
# Talking to the linked project
# --------------------------------------------------------------------------- #
def supabase_bin() -> str:
    exe = os.environ.get("SUPABASE_BIN") or shutil.which("supabase")
    if not exe:
        sys.exit("supabase CLI not found on PATH; set SUPABASE_BIN")
    return exe


def db_query(args: list[str]) -> dict:
    """Run `supabase db query --linked` and return its JSON payload."""
    proc = subprocess.run([supabase_bin(), "db", "query", "--linked", *args],
                          cwd=REPO, capture_output=True)
    text = (proc.stdout + proc.stderr).decode("utf-8", "replace")
    start = text.find("{")
    if start < 0:
        raise SuiteError(text.strip()[-800:] or f"supabase exited {proc.returncode}")
    payload, _ = json.JSONDecoder().raw_decode(text, start)
    return payload


def error_message(payload: dict) -> str:
    msg = (payload.get("error") or {}).get("message", "")
    if "status 400: " in msg:                       # the API nests the database error
        try:
            msg = json.loads(msg.split("status 400: ", 1)[1])["message"]
        except (ValueError, KeyError):
            pass
    return msg.removeprefix("Failed to run sql query: ")


def snapshot() -> dict[str, int]:
    payload = db_query([SNAPSHOT_SQL])
    if "rows" not in payload:
        raise SuiteError("snapshot failed: " + error_message(payload))
    return {r["item"]: int(r["n"]) for r in payload["rows"]}


def run_suite(path: Path) -> list[str]:
    """Execute one suite and return its TAP lines."""
    batch, _ = build_batch(path.read_text(encoding="utf-8"))
    with tempfile.NamedTemporaryFile("w", suffix=".sql", delete=False, encoding="utf-8") as f:
        f.write(batch)
        tmp = f.name
    try:
        payload = db_query(["-f", tmp])
    finally:
        os.unlink(tmp)

    if "rows" in payload:
        # The batch always ends by raising. Getting rows back means it did not
        # abort, so nothing guarantees the fixtures were rolled back.
        raise PermissionError("the batch completed without aborting: check the database "
                              "for saved fixture rows immediately")
    msg = error_message(payload)
    if "TAPOUT" not in msg:
        raise SuiteError(msg)                     # failed before reaching the end
    out = msg.split("TAPOUT", 1)[1]
    return [ln for ln in out.split("\n") if ln.strip() and not ln.startswith("CONTEXT:")]


# --------------------------------------------------------------------------- #
# Reporting
# --------------------------------------------------------------------------- #
def report(path: Path, tap: list[str]) -> bool:
    """Print a suite's results; return True when every planned test passed."""
    planned = next((int(m.group(1)) for ln in tap if (m := PLAN_RE.match(ln))), None)
    results = [(m.group(1), int(m.group(2)), ln) for ln in tap if (m := TAP_LINE_RE.match(ln))]
    failed = [ln for kind, _, ln in results if kind == "not ok"]
    seen = [num for _, num, _ in results]

    print(f"\n{path.relative_to(REPO) if path.is_relative_to(REPO) else path}")
    for i, ln in enumerate(tap):
        if ln.startswith("not ok"):
            print("  " + ln)
            for diag in tap[i + 1:]:
                if not diag.startswith("#"):
                    break
                print("    " + diag)

    ok = not failed
    if planned is not None:
        missing = sorted(set(range(1, planned + 1)) - set(seen))
        if missing:
            ok = False
            print(f"  output not captured for test(s) {missing} — each was written with a "
                  "function run_linked.py does not recognise, or the suite stopped early")
        passed = len(results) - len(failed)
        print(f"  {passed}/{planned} passed" + ("" if ok else "  FAILED"))
    else:
        print(f"  {len(results) - len(failed)}/{len(results)} passed (no plan found)")
    return ok


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    paths = [Path(a).resolve() for a in argv] or sorted(TESTS_DIR.glob("*.sql"))
    if not paths:
        print("no test files found")
        return 2

    # Refuse unsafe suites before touching the database at all.
    for p in paths:
        try:
            build_batch(p.read_text(encoding="utf-8"))
        except PermissionError as e:
            print(f"{p.name}: {e}")
            return 3

    before = snapshot()
    worst = 0
    for p in paths:
        try:
            worst = max(worst, 0 if report(p, run_suite(p)) else 1)
        except SuiteError as e:
            print(f"\n{p.name}\n  suite error before TAP output:\n    "
                  + str(e).replace("\n", "\n    "))
            worst = max(worst, 2)
        except PermissionError as e:
            print(f"\n{p.name}\n  {e}")
            worst = 3
    after = snapshot()

    changed = {k: (before.get(k), after.get(k)) for k in before.keys() | after.keys()
               if before.get(k) != after.get(k)}
    print()
    if changed:
        print("DATABASE CHANGED during the run — nothing should persist. Investigate; "
              "concurrent use of the project can also cause this:")
        for k, (b, a) in sorted(changed.items()):
            print(f"  {k}: {b} -> {a}")
        worst = 3
    else:
        tables = sum(1 for k in before if not k.startswith("extension:"))
        print(f"no trace left: {tables} tables unchanged, pgtap extension unchanged")
    return worst


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
