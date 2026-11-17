"""Small helper to fetch/replace one stored procedure on a configured MES source.

Usage:
    python -I scripts/proc_tool.py get  --source jiban-mes-prod --name PDA_CKDPacking_YN --out var/PDA_CKDPacking_YN.sql
    python -I scripts/proc_tool.py put  --source jiban-mes-prod --file var/PDA_CKDPacking_YN.sql --dry-run
    python -I scripts/proc_tool.py put  --source jiban-mes-prod --file var/PDA_CKDPacking_YN.sql
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pymssql

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "db" / "catalog"
SECRETS = ROOT / "secrets"


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, raw = line.split("=", 1)
        values[key.strip()] = raw.strip().strip("'\"")
    return values


def connect(source: str):
    catalog = read_env(CATALOG / source)
    secrets = read_env(SECRETS / f"{source}.env")
    return pymssql.connect(
        server=secrets.get("DB_HOST") or catalog.get("HOST", ""),
        port=int(secrets.get("DB_PORT") or "1433"),
        user=secrets.get("DB_USER", ""),
        password=secrets.get("DB_PASSWORD", ""),
        database=catalog.get("DB", ""),
        login_timeout=10,
        timeout=45,
        as_dict=True,
    )


def normalize(name: str) -> str:
    return name if "." in name else f"dbo.{name}"


def cmd_get(args: argparse.Namespace) -> int:
    name = normalize(args.name)
    with connect(args.source) as conn:
        cur = conn.cursor()
        cur.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(%s)) AS definition", (name,))
        row = cur.fetchone() or {}
    definition = row.get("definition")
    if definition is None:
        print(f"NOT FOUND: {name}", file=sys.stderr)
        return 1
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(definition, encoding="utf-8")
    print(f"{name}: {len(definition)} chars -> {out}")
    return 0


def cmd_put(args: argparse.Namespace) -> int:
    sql = Path(args.file).read_text(encoding="utf-8")
    name = normalize(args.name) if args.name else None
    with connect(args.source) as conn:
        cur = conn.cursor()
        if args.dry_run:
            cur.execute("BEGIN TRAN")
        try:
            cur.execute(sql)
            if name:
                cur.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(%s)) AS definition", (name,))
                row = cur.fetchone() or {}
                definition = row.get("definition") or ""
                print(f"applied in transaction: {name}, {len(definition)} chars")
            else:
                print("applied in transaction")
            if args.dry_run:
                cur.execute("ROLLBACK")
                print("dry-run: rolled back")
            else:
                conn.commit()
                print("committed")
        except Exception:
            if args.dry_run:
                try:
                    cur.execute("ROLLBACK")
                except Exception:
                    pass
            else:
                conn.rollback()
            raise
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    get = sub.add_parser("get")
    get.add_argument("--source", required=True)
    get.add_argument("--name", required=True)
    get.add_argument("--out", required=True)
    get.set_defaults(func=cmd_get)

    put = sub.add_parser("put")
    put.add_argument("--source", required=True)
    put.add_argument("--file", required=True)
    put.add_argument("--name", default="")
    put.add_argument("--dry-run", action="store_true")
    put.set_defaults(func=cmd_put)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
