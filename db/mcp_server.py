"""OrBit 单库 MCP 服务。每个进程只读取 --source 指定的一套库。"""

from __future__ import annotations

import argparse
import re
import time
from datetime import date, datetime, time as time_value
from decimal import Decimal
from pathlib import Path
from typing import Any

import pymssql
from mcp.server.fastmcp import FastMCP

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "db" / "catalog"
SECRETS = ROOT / "secrets"
SOURCE_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PROCEDURE_PATTERN = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*$")
PARAMETER_PATTERN = re.compile(r"^@?[A-Za-z_][A-Za-z0-9_]*$")
CONNECT_ATTEMPTS = 3
MAX_ROWS = 1000


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, raw = line.split("=", 1)
        values[key.strip()] = raw.strip().strip("'\"")
    return values


def json_value(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, (datetime, date, time_value)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (bytes, bytearray)):
        return "0x" + bytes(value).hex()
    return str(value)


def json_row(row: dict) -> dict:
    return {str(key): json_value(value) for key, value in row.items()}


def sql_error(error: Exception) -> str:
    parts = []
    for value in getattr(error, "args", ()):
        if isinstance(value, bytes):
            parts.append(value.decode("utf-8", errors="replace"))
        else:
            parts.append(str(value))
    return " ".join(parts).strip() or str(error)


def transient_connect_error(error: Exception) -> bool:
    if isinstance(error, (TimeoutError, ConnectionError)):
        return True
    text = sql_error(error).casefold()
    return any(text_part in text for text_part in (
        "unable to connect", "server is unavailable", "timed out", "timeout",
        "network", "connection reset", "connection refused", "broken pipe",
    ))


def validate_query(sql: str) -> str:
    statement = sql.strip()
    if not statement:
        raise ValueError("请输入 SELECT 查询")
    # 查询工具只允许单条 SELECT（含 CTE）。字符串和注释先移除，避免误判其中的关键字。
    code = re.sub(r"'(?:''|[^'])*'", "''", statement)
    code = re.sub(r"--[^\r\n]*|/\*.*?\*/", " ", code, flags=re.DOTALL)
    code = re.sub(r"\[[^\]]*\]", " ", code)
    if not re.match(r"^(?:SELECT|WITH)\b", code, flags=re.IGNORECASE):
        raise ValueError("query 只允许 SELECT 查询；执行存储过程请使用 execute")
    if re.search(r";\s*\S", code):
        raise ValueError("query 一次只能执行一条查询")
    forbidden = r"\b(?:INSERT|UPDATE|DELETE|MERGE|EXECUTE|EXEC|ALTER|DROP|CREATE|TRUNCATE|GRANT|REVOKE|DENY|BACKUP|RESTORE|DBCC|INTO)\b"
    if re.search(forbidden, code, flags=re.IGNORECASE):
        raise ValueError("query 是只读工具，不允许写入或管理操作")
    return statement


def validate_procedure(name: str) -> str:
    name = name.strip()
    if not PROCEDURE_PATTERN.fullmatch(name):
        raise ValueError("存储过程名只支持 名称 或 dbo.名称")
    return name if "." in name else f"dbo.{name}"


class MesDatabase:
    """连接不跨调用复用，避免失效连接污染后续对话。"""

    def __init__(self, source: str):
        if not SOURCE_PATTERN.fullmatch(source):
            raise ValueError("数据源名称不合法")
        catalog_path = CATALOG / source
        secret_path = SECRETS / f"{source}.env"
        if not catalog_path.is_file() or not secret_path.is_file():
            raise ValueError(f"没有 {source} 的数据库配置")
        self.source = source
        self.catalog = read_env(catalog_path)
        self.secrets = read_env(secret_path)
        # 工具描述里带上真实库和环境，调用前就能核对，不靠记工具名。
        stage = "测试" if self.catalog.get("STAGE") == "test" else "正式"
        host = self.secrets.get("DB_HOST") or self.catalog.get("HOST", "")
        label = self.catalog.get("LABEL", source)
        self.scope = f"{label}（{self.catalog.get('DB', '')} @ {host}，{stage}库）"
        self.tools = {
            item.strip().rsplit("-", 1)[-1]
            for item in self.catalog.get("TOOLS", "").split(",")
            if item.strip()
        }

    def allows(self, tool: str) -> bool:
        return tool in self.tools

    def connect(self):
        options = {
            "server": self.secrets.get("DB_HOST") or self.catalog.get("HOST", ""),
            "port": int(self.secrets.get("DB_PORT") or "1433"),
            "user": self.secrets.get("DB_USER", ""),
            "password": self.secrets.get("DB_PASSWORD", ""),
            "database": self.catalog.get("DB", ""),
            "login_timeout": 10,
            "timeout": 45,
            "as_dict": True,
        }
        for attempt in range(CONNECT_ATTEMPTS):
            try:
                return pymssql.connect(**options)
            except Exception as error:
                if attempt + 1 >= CONNECT_ATTEMPTS or not transient_connect_error(error):
                    raise RuntimeError(f"连不上 {self.source}: {sql_error(error)}") from None
                time.sleep(0.25 * (2 ** attempt))
        raise AssertionError("unreachable")

    @staticmethod
    def result_set(cursor, limit: int) -> dict:
        rows = cursor.fetchmany(limit + 1)
        return {
            "columns": [str(item[0]) for item in (cursor.description or [])],
            "rows": [json_row(row) for row in rows[:limit]],
            "truncated": len(rows) > limit,
        }

    def query(self, sql: str, limit: int) -> dict:
        statement = validate_query(sql)
        limit = max(1, min(int(limit), MAX_ROWS))
        connection = self.connect()
        try:
            cursor = connection.cursor()
            cursor.execute(statement)
            result = self.result_set(cursor, limit)
            return {"source": self.source, **result, "rowCount": len(result["rows"])}
        finally:
            try:
                connection.rollback()
            except Exception:
                pass
            connection.close()

    def procedure(self, name: str) -> dict:
        procedure_name = validate_procedure(name)
        connection = self.connect()
        try:
            cursor = connection.cursor()
            cursor.execute(
                "SELECT OBJECT_DEFINITION(OBJECT_ID(%s)) AS definition",
                (procedure_name,),
            )
            row = cursor.fetchone() or {}
            definition = row.get("definition")
            if definition is None:
                raise ValueError(f"库里没有 {procedure_name} 这个存储过程，或没有查看权限")
            return {"source": self.source, "name": procedure_name, "definition": definition}
        finally:
            connection.close()

    def execute(self, name: str, parameters: dict[str, Any]) -> dict:
        procedure_name = validate_procedure(name)
        if any(not PARAMETER_PATTERN.fullmatch(key) for key in parameters):
            raise ValueError("存储过程参数名不合法")
        connection = self.connect()
        try:
            cursor = connection.cursor()
            # 执行类工具绝不自动重试，避免网络故障导致重复业务写入。
            cursor.callproc(procedure_name, parameters)
            results = []
            while True:
                if cursor.description:
                    results.append(self.result_set(cursor, MAX_ROWS))
                if not cursor.nextset():
                    break
            connection.commit()
            return {"source": self.source, "name": procedure_name, "resultSets": results}
        except Exception:
            try:
                connection.rollback()
            except Exception:
                pass
            raise
        finally:
            connection.close()


def create_server(database: MesDatabase) -> FastMCP:
    server = FastMCP(database.source, log_level="WARNING")

    if database.allows("query"):
        @server.tool(description=f"在 {database.scope} 执行一条只读 SELECT 查询，支持 CTE；默认最多返回 200 行。")
        def query(sql: str, limit: int = 200) -> dict:
            return database.query(sql, limit)

    if database.allows("procedure"):
        @server.tool(description=f"查看 {database.scope} 中一个存储过程的完整定义。name 可写为 名称 或 dbo.名称。")
        def procedure(name: str) -> dict:
            return database.procedure(name)

    if database.allows("execute"):
        @server.tool(description=f"在 {database.scope} 执行一个存储过程。parameters 使用参数名到参数值的 JSON 对象；该操作可能写入业务数据。")
        def execute(name: str, parameters: dict[str, Any] = {}) -> dict:
            return database.execute(name, parameters)

    return server


def main() -> None:
    sources = sorted(path.name for path in CATALOG.iterdir() if path.is_file() and SOURCE_PATTERN.fullmatch(path.name))
    parser = argparse.ArgumentParser(description="OrBit 单库 MCP 服务")
    parser.add_argument("--source", required=True, choices=sources)
    args = parser.parse_args()
    create_server(MesDatabase(args.source)).run(transport="stdio")


if __name__ == "__main__":
    main()
