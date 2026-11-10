"""工作台后端。目录给页面看，大模型调用走 agent。"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from agent.llm import describe, guide
CATALOG = ROOT / "db" / "catalog"
SKILLS = ROOT / ".AGENTS" / "skills"
LIBRARY = ROOT / "library"
SECRETS = ROOT / "secrets"
LAYOUT = (
    ("web", "工作台页面"),
    ("server", "接口"),
    ("agent", "大模型"),
    ("db", "数据库目录"),
    (".AGENTS/skills", "技能"),
    ("super-agent", "对用户说的话"),
    ("secrets", "凭据"),
    ("scripts", "启动"),
    ("AGENT.md", "会话入口"),
    ("README.md", "项目说明"),
)

app = FastAPI(title="OrBit 工作台")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:3000", "http://localhost:3000"],
    allow_methods=["GET", "POST"],
    allow_headers=[],
)


def parse_catalog(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        if "=" not in line or line.startswith("#"):
            continue
        key, raw = line.split("=", 1)
        raw = raw.strip()
        if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "'\"":
            raw = raw[1:-1]
        values[key] = raw
    return values


def translate_texts(cursor, modules) -> dict[str, str]:
    """按模块名批量查 SysText 中文翻译，模块名原样交给数据库匹配。"""
    names = list(dict.fromkeys(str(item) for item in modules if item))
    if not names:
        return {}
    values = ", ".join(["(%s)"] * len(names))
    cursor.execute(
        "SELECT q.name AS requested, tx.Text2 "
        f"FROM (VALUES {values}) AS q(name) "
        "LEFT JOIN dbo.SysText AS tx WITH (NOLOCK) "
        "ON tx.TextOwner = N'[Public Text]' AND tx.TextModule = q.name",
        tuple(names),
    )
    translated: dict[str, str] = {}
    for row in cursor.fetchall():
        requested = str(row.get("requested") or "")
        if requested and requested not in translated:
            translated[requested] = str(row.get("Text2") or "")
    return translated


def environment(env_id: str, values: dict[str, str]) -> dict:
    tools = [item.strip() for item in values.get("TOOLS", "").split(",") if item.strip()]
    return {
        "id": env_id,
        "order": int(values.get("ORDER", "0")),
        "label": values.get("LABEL", env_id),
        "host": values.get("HOST", ""),
        "machine": values.get("MACHINE", ""),
        "database": values.get("DB", ""),
        "kind": values.get("STAGE", "prod"),
        "caution": values.get("CAUTION", ""),
        "tools": tools,
    }


def skill_text(text: str) -> tuple[str, str]:
    if not text.startswith("---"):
        return "", ""
    end = text.find("\n---", 3)
    if end < 0:
        return "", ""
    name = ""
    lines: list[str] = []
    reading = False
    for line in text[3:end].splitlines():
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip()
            reading = False
        elif line.startswith("description:"):
            reading = True
            rest = line.split(":", 1)[1].strip()
            if rest and rest not in {">-", ">", "|"}:
                lines.append(rest)
        elif reading and line[:1] in {" ", "\t"}:
            lines.append(line.strip())
        else:
            reading = False
    return name, " ".join(lines)


def layout() -> list[dict]:
    items = []
    for rel, label in LAYOUT:
        items.append({"path": rel, "label": label, "present": (ROOT / rel).exists()})
    return items


def skill_page(skill_id: str) -> dict:
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", skill_id):
        raise HTTPException(status_code=404, detail="没有这份技能")
    page = SKILLS / skill_id / "SKILL.md"
    if not page.is_file():
        raise HTTPException(status_code=404, detail="没有这份技能")
    text = page.read_text(encoding="utf-8")
    name, _description = skill_text(text)
    return {
        "id": skill_id,
        "name": name or skill_id,
        "path": f".AGENTS/skills/{skill_id}/SKILL.md",
        "text": text,
    }


def skills() -> list[dict]:
    found = []
    if not SKILLS.is_dir():
        return found
    for folder in sorted(path for path in SKILLS.iterdir() if path.is_dir()):
        page = folder / "SKILL.md"
        name, description = skill_text(page.read_text(encoding="utf-8")) if page.is_file() else ("", "")
        found.append({"id": folder.name, "name": name or folder.name, "description": description})
    return found


@app.get("/api/skills/{skill_id}")
def skill_document(skill_id: str) -> dict:
    return skill_page(skill_id)


def function_folder(plant: str, command: str) -> Path:
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", plant):
        raise HTTPException(status_code=404, detail="没有这份功能")
    if not re.fullmatch(r"[A-Za-z0-9]+", command):
        raise HTTPException(status_code=404, detail="没有这份功能")
    folder = (LIBRARY / plant / command).resolve()
    try:
        folder.relative_to(LIBRARY.resolve())
    except ValueError:
        raise HTTPException(status_code=404, detail="没有这份功能") from None
    return folder


def skeleton_pack(plant: str, command: str) -> dict:
    return {
        "plant": plant,
        "source": f"{plant}-mes-prod",
        "command": command,
        "name": command,
        "application": "WMS" if "-wms-" in plant else "MES",
        "kind": "",
        "pluginName": command,
        "metadata": "",
        "objects": [],
        "missing": True,
    }


def legacy_object(data: dict) -> dict:
    table = data.get("table")
    procedures = data.get("procedures")
    pulled = data.get("pulled")
    return {
        "id": "",
        "name": str(data.get("command") or ""),
        "text": str(data.get("name") or ""),
        "parentId": "",
        "sequence": "",
        "depth": 1,
        "table": table if isinstance(table, dict) else {"name": "", "columns": []},
        "procedures": procedures if isinstance(procedures, list) else [],
        "pulled": pulled if isinstance(pulled, dict) else {},
    }


def function_pack(plant: str, command: str) -> dict:
    folder = function_folder(plant, command)
    page = folder / "object.json"
    if not page.is_file():
        data = skeleton_pack(plant, command)
        try:
            connection = open_database(str(data.get("source") or ""))
            try:
                cursor = connection.cursor(as_dict=True)
                plugin = find_plugin(cursor, command)
                root_id = str(plugin.get("MetadataId") or "").strip()
                if root_id:
                    data["objects"] = merge_objects(folder, data, metadata_tree(cursor, root_id), plugin)
                    data["name"] = str(plugin.get("PluginName") or data["name"])
                    data["pluginName"] = data["name"]
                    data["kind"] = plugin_kind(plugin.get("PluginFileName"))
                    data["metadata"] = str(plugin.get("PluginDescription") or "")
            finally:
                connection.close()
        except Exception:
            data["objects"] = []
        data["path"] = f"library/{plant}/{command}"
        return data
    data = json.loads(page.read_text(encoding="utf-8"))
    objects = data.get("objects")
    if not isinstance(objects, list) or not objects:
        objects = [legacy_object(data)]
    for item in objects:
        procedures = []
        for proc in item.get("procedures") or []:
            file_name = str(proc.get("file") or "")
            sql = ""
            if re.fullmatch(r"[A-Za-z0-9_]+\.sql", file_name):
                sql_path = folder / file_name
                if sql_path.is_file():
                    sql = sql_path.read_text(encoding="utf-8")
            procedures.append({**proc, "sql": sql})
        item["procedures"] = procedures
        value_lists = []
        for entry in item.get("valueLists") or []:
            file_name = str(entry.get("file") or "")
            sql = ""
            if re.fullmatch(r"[A-Za-z0-9_]+\.sql", file_name):
                sql_path = folder / file_name
                if sql_path.is_file():
                    sql = sql_path.read_text(encoding="utf-8")
            value_lists.append({**entry, "sql": sql})
        item["valueLists"] = value_lists
        style = item.get("style")
        if isinstance(style, dict):
            for group in (style.get("main") or {}).get("groups") or []:
                for method in group.get("methods") or []:
                    file_name = str(method.get("file") or "")
                    definition = ""
                    if re.fullmatch(r"[A-Za-z0-9_]+\.sql", file_name):
                        sql_path = folder / file_name
                        if sql_path.is_file():
                            definition = sql_path.read_text(encoding="utf-8")
                    method["definition"] = definition
    data["objects"] = objects
    data.pop("table", None)
    data.pop("procedures", None)
    data["path"] = f"library/{plant}/{command}"
    return data


@app.get("/api/functions/{plant}/{command}")
def function_document(plant: str, command: str) -> dict:
    return function_pack(plant, command)


PLUGIN_KINDS = {
    "Plugin Standard.dll": "标准元对象",
    "Plugin Query.dll": "查询元对象",
    "PluginMESStaticTxn.dll": "静态事务对象",
    "PluginMESMobile.dll": "移动事务对象",
    "Plugin Workflow.dll": "工作流对象",
}
TYPES_WITH_LENGTH = {"char", "varchar", "nchar", "nvarchar", "binary", "varbinary"}
PROCEDURE_ROLES = (
    ("MainView", "MainView"),
    ("TreeView", "TreeView"),
    ("SaveData", "MainSave"),
    ("DeleteView", "MainDelete"),
)


def plugin_kind(file_name: str | None) -> str:
    name = str(file_name or "").strip()
    if name in PLUGIN_KINDS:
        return PLUGIN_KINDS[name]
    return name[:-4] if name.lower().endswith(".dll") else name


def sql_type(data_type: str | None, length, precision, scale) -> str:
    name = str(data_type or "").lower()
    if name in TYPES_WITH_LENGTH:
        return f"{name}(max)" if length in (None, -1) else f"{name}({length})"
    if name in {"decimal", "numeric"} and precision is not None:
        return f"{name}({precision},{scale})"
    return name


def write_sql_file(path: Path, text: str) -> None:
    """存储过程文本统一写为 LF，避免 Windows 换行转换把 \\r\\n 变成 \\r\\r\\n。"""
    path.write_text(text.replace("\r\n", "\n").replace("\r", "\n"), encoding="utf-8", newline="\n")


def environment_secrets(env_id: str) -> tuple[dict[str, str], dict[str, str]]:
    catalog_path = CATALOG / env_id
    secret_path = SECRETS / f"{env_id}.env"
    if not catalog_path.is_file() or not secret_path.is_file():
        raise HTTPException(status_code=400, detail=f"没有 {env_id} 的库配置")
    return (
        parse_catalog(catalog_path.read_text(encoding="utf-8")),
        parse_catalog(secret_path.read_text(encoding="utf-8")),
    )


def source_library(plant: str, command: str, create: bool = False) -> tuple[Path, dict, str]:
    folder = function_folder(plant, command)
    page = folder / "object.json"
    if page.is_file():
        data = json.loads(page.read_text(encoding="utf-8"))
    else:
        data = skeleton_pack(plant, command)
        if create:
            folder.mkdir(parents=True, exist_ok=True)
    source = str(data.get("source") or "").strip() or f"{plant}-mes-prod"
    return folder, data, source


def open_database(source: str):
    catalog, secrets = environment_secrets(source)
    try:
        import pymssql
    except ImportError:
        raise HTTPException(status_code=500, detail="服务端没有安装 pymssql") from None
    try:
        return pymssql.connect(
            server=secrets.get("DB_HOST") or catalog.get("HOST", ""),
            port=int(secrets.get("DB_PORT") or "1433"),
            user=secrets.get("DB_USER", ""),
            password=secrets.get("DB_PASSWORD", ""),
            database=catalog.get("DB", ""),
            login_timeout=20,
            timeout=60,
        )
    except Exception as error:
        raise HTTPException(status_code=502, detail=f"连不上 {source}: {error}") from None


def find_plugin(cursor, command: str) -> dict:
    cursor.execute(
        "SELECT PluginCommand, PluginName, PluginDescription, PluginFileName, MetadataId "
        "FROM SysPlugIn WHERE RTRIM(PluginCommand) = %s",
        (command,),
    )
    plugins = cursor.fetchall()
    if not plugins:
        raise HTTPException(status_code=404, detail=f"库里没有 {command} 这个命令")
    return next((row for row in plugins if plugin_kind(row.get("PluginFileName")) in PLUGIN_KINDS.values()), plugins[0])


def find_metadata_by_id(cursor, metadata_id: str) -> dict:
    cursor.execute(
        "SELECT RTRIM(MetadataId) AS MetadataId, MetadataName, RTRIM(ParentMetadataId) AS ParentMetadataId, "
        "TreeView, MainView, MainSave, MainDelete, ObjectId "
        "FROM SysMetadata WHERE RTRIM(MetadataId) = %s",
        (metadata_id,),
    )
    metadata = cursor.fetchall()
    if not metadata:
        raise HTTPException(status_code=404, detail=f"库里没有 {metadata_id} 这个元对象")
    return metadata[0]


def metadata_tree(cursor, root_id: str) -> list[dict]:
    cursor.execute(
        """
        ;WITH tree AS (
            SELECT RTRIM(m.MetadataId) AS MetadataId, m.MetadataName,
                   RTRIM(m.ParentMetadataId) AS ParentMetadataId, m.Sequence,
                   m.TreeView, m.MainView, m.MainSave, m.MainDelete, m.ObjectId,
                   1 AS Depth
            FROM dbo.SysMetadata AS m WITH (NOLOCK)
            WHERE RTRIM(m.MetadataId) = %s
            UNION ALL
            SELECT RTRIM(m.MetadataId), m.MetadataName, RTRIM(m.ParentMetadataId), m.Sequence,
                   m.TreeView, m.MainView, m.MainSave, m.MainDelete, m.ObjectId,
                   t.Depth + 1
            FROM tree AS t
            INNER JOIN dbo.SysMetadata AS m WITH (NOLOCK)
                    ON RTRIM(m.ParentMetadataId) = t.MetadataId
        )
        SELECT t.MetadataId, t.MetadataName, t.ParentMetadataId, t.Sequence,
               t.TreeView, t.MainView, t.MainSave, t.MainDelete, t.ObjectId
        FROM tree AS t
        """,
        (root_id,),
    )
    rows = cursor.fetchall()
    if not rows:
        return []
    texts = translate_texts(cursor, [row.get("MetadataName") for row in rows])
    children: dict[str, list[dict]] = {}
    for row in rows:
        row["MetadataId"] = str(row.get("MetadataId") or "").strip()
        row["ParentMetadataId"] = str(row.get("ParentMetadataId") or "").strip()
        row["MetadataText"] = texts.get(str(row.get("MetadataName") or ""), "")
        children.setdefault(row["ParentMetadataId"], []).append(row)

    def sequence_key(row: dict) -> tuple:
        text = str(row.get("Sequence") or "").strip()
        try:
            return 0, int(text), ""
        except ValueError:
            return 1, 0, text

    root = next((row for row in rows if row["MetadataId"] == root_id), None)
    if not root:
        return []
    ordered: list[dict] = []

    def walk(row: dict, depth: int) -> None:
        row["Depth"] = depth
        ordered.append(row)
        for child in sorted(children.get(row["MetadataId"], []), key=sequence_key):
            walk(child, depth + 1)

    walk(root, 1)
    return ordered


def metadata_object(row: dict, plugin: dict) -> dict:
    text = str(row.get("MetadataText") or "").strip()
    if row.get("Depth") == 1:
        text = str(plugin.get("PluginName") or text).strip()
    procedures = []
    for role, column in PROCEDURE_ROLES:
        name = str(row.get(column) or "").strip()
        if name:
            procedures.append({"role": role, "name": name, "file": f"{name}.sql"})
    return {
        "id": row["MetadataId"],
        "name": str(row.get("MetadataName") or "").strip(),
        "text": text,
        "parentId": row["ParentMetadataId"],
        "sequence": str(row.get("Sequence") or "").strip(),
        "depth": int(row.get("Depth") or 1),
        "table": {"name": "", "columns": []},
        "procedures": procedures,
        "pulled": {},
    }


def merge_objects(folder: Path, data: dict, rows: list[dict], plugin: dict) -> list[dict]:
    existing = data.get("objects")
    previous = {str(item.get("id") or ""): item for item in existing or []}
    if not isinstance(existing, list) or not existing:
        previous[""] = legacy_object(data)
    objects = []
    for row in rows:
        entry = metadata_object(row, plugin)
        old = previous.get(entry["id"])
        if not old and entry["depth"] == 1:
            old = previous.get("")
        if old:
            if isinstance(old.get("table"), dict):
                entry["table"] = old["table"]
            if isinstance(old.get("style"), dict):
                entry["style"] = old["style"]
            if isinstance(old.get("pulled"), dict):
                entry["pulled"] = old["pulled"]
            if isinstance(old.get("valueLists"), list):
                entry["valueLists"] = old["valueLists"]
            old_by_role = {str(item.get("role")): item for item in old.get("procedures") or []}
            new_roles = {str(item.get("role")): item for item in entry["procedures"]}
            for role, item in old_by_role.items():
                file_name = str(item.get("file") or "")
                fresh = new_roles.get(role)
                if file_name and (not fresh or fresh["file"] != file_name) and re.fullmatch(r"[A-Za-z0-9_]+\.sql", file_name):
                    (folder / file_name).unlink(missing_ok=True)
        objects.append(entry)
    return objects


def ensure_objects(cursor, folder: Path, data: dict, plugin: dict) -> list[dict]:
    objects = data.get("objects")
    if isinstance(objects, list) and objects and all(str(item.get("id") or "").strip() for item in objects):
        return objects
    root_id = str(plugin.get("MetadataId") or "").strip()
    if not root_id:
        raise HTTPException(status_code=404, detail=f"{plugin.get('PluginCommand')} 没有对应的元对象")
    data["objects"] = merge_objects(folder, data, metadata_tree(cursor, root_id), plugin)
    if not data["objects"]:
        raise HTTPException(status_code=404, detail=f"{plugin.get('PluginCommand')} 没有对应的元数据")
    return data["objects"]


def select_object(data: dict, object_id: str | None) -> dict:
    objects = data.get("objects") or []
    if object_id:
        found = next((item for item in objects if str(item.get("id") or "") == object_id), None)
        if not found:
            raise HTTPException(status_code=404, detail=f"{object_id} 不属于这个功能")
        return found
    if not objects:
        raise HTTPException(status_code=404, detail="这个功能还没有元对象")
    return objects[0]


def metadata_table_name(cursor, metadata: dict) -> str:
    cursor.execute("SELECT ObjectName FROM SysObject WHERE ObjectId = %s", (metadata.get("ObjectId"),))
    objects = cursor.fetchall()
    name = str((objects[0].get("ObjectName") if objects else "") or metadata.get("MetadataName") or "").strip()
    if not name:
        raise HTTPException(status_code=404, detail="没有对应的业务表")
    return name


def write_object(folder: Path, data: dict) -> None:
    data.pop("missing", None)
    data.pop("table", None)
    data.pop("procedures", None)
    (folder / "object.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def mark_pulled(data: dict, key: str) -> None:
    pulled = data.get("pulled")
    if not isinstance(pulled, dict):
        pulled = {}
    pulled[key] = datetime.now().astimezone().isoformat(timespec="seconds")
    data["pulled"] = pulled


def resolve_procedure(column: str, metadata: dict) -> str:
    return str(metadata.get(column) or "").strip()


def sync_plugin(data: dict, plant: str, command: str, source: str, plugin: dict, metadata_name: str) -> None:
    data.update({
        "plant": plant,
        "source": source,
        "command": command,
        "name": str(plugin.get("PluginName") or data.get("name") or command),
        "application": "WMS" if "-wms-" in source else "MES",
        "kind": plugin_kind(plugin.get("PluginFileName")) or str(data.get("kind") or ""),
        "pluginName": str(plugin.get("PluginName") or data.get("pluginName") or command),
        "metadata": str(plugin.get("PluginDescription") or metadata_name or ""),
    })


@app.post("/api/functions/{plant}/{command}/pull/meta")
def pull_meta(plant: str, command: str) -> dict:
    folder, data, source = source_library(plant, command, create=True)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        root_id = str(plugin.get("MetadataId") or "").strip()
        if not root_id:
            raise HTTPException(status_code=404, detail=f"{command} 没有对应的元对象")
        rows = metadata_tree(cursor, root_id)
        if not rows:
            raise HTTPException(status_code=404, detail=f"{command} 没有对应的元数据")
        data["objects"] = merge_objects(folder, data, rows, plugin)
        sync_plugin(data, plant, command, source, plugin, str(rows[0].get("MetadataName") or ""))
    finally:
        connection.close()

    mark_pulled(data, "meta")
    write_object(folder, data)
    return function_pack(plant, command)


@app.post("/api/functions/{plant}/{command}/pull/table")
def pull_table(plant: str, command: str, object_id: str | None = Query(None, alias="object")) -> dict:
    folder, data, source = source_library(plant, command, create=True)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        ensure_objects(cursor, folder, data, plugin)
        target = select_object(data, object_id)
        metadata = find_metadata_by_id(cursor, str(target["id"]))
        table_name = metadata_table_name(cursor, metadata)

        cursor.execute(
            "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, "
            "IS_NULLABLE, COLUMNPROPERTY(OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME), COLUMN_NAME, 'IsIdentity') AS IS_IDENTITY "
            "FROM INFORMATION_SCHEMA.COLUMNS "
            "WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = %s ORDER BY ORDINAL_POSITION",
            (table_name,),
        )
        columns = cursor.fetchall()
        if not columns:
            raise HTTPException(status_code=404, detail=f"库里没有 {table_name} 这张表")

        cursor.execute(
            "SELECT c.name FROM sys.indexes i "
            "JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id "
            "JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id "
            "WHERE i.object_id = OBJECT_ID(%s) AND i.is_primary_key = 1",
            (f"dbo.{table_name}",),
        )
        primary_keys = {row["name"] for row in cursor.fetchall()}

        cursor.execute(
            "SELECT COL_NAME(major_id, minor_id) AS ColumnName, CAST(value AS nvarchar(4000)) AS Description "
            "FROM sys.extended_properties "
            "WHERE name = N'MS_Description' AND major_id = OBJECT_ID(%s) AND minor_id > 0",
            (f"dbo.{table_name}",),
        )
        descriptions = {
            str(row["ColumnName"]): str(row["Description"] or "").strip()
            for row in cursor.fetchall()
        }
        texts = translate_texts(cursor, [str(row["COLUMN_NAME"]) for row in columns])
        sync_plugin(data, plant, command, source, plugin, str((data["objects"] or [{}])[0].get("name") or ""))
    finally:
        connection.close()

    old_descriptions = {
        str(column.get("name")): str(column.get("description") or "")
        for column in (target.get("table") or {}).get("columns") or []
    }
    target["table"] = {
        "name": table_name,
        "columns": [
            {
                "name": row["COLUMN_NAME"],
                "type": sql_type(
                    row["DATA_TYPE"],
                    row["CHARACTER_MAXIMUM_LENGTH"],
                    row["NUMERIC_PRECISION"],
                    row["NUMERIC_SCALE"],
                ),
                "nullable": row["IS_NULLABLE"] == "YES",
                "identity": bool(row["IS_IDENTITY"]),
                "primaryKey": row["COLUMN_NAME"] in primary_keys,
                "description": descriptions.get(row["COLUMN_NAME"])
                or texts.get(str(row["COLUMN_NAME"]), "")
                or old_descriptions.get(row["COLUMN_NAME"], ""),
            }
            for row in columns
        ],
    }
    mark_pulled(target, "table")
    write_object(folder, data)
    return function_pack(plant, command)


@app.post("/api/functions/{plant}/{command}/pull/procedure/{role}")
def pull_procedure(
    plant: str,
    command: str,
    role: str,
    object_id: str | None = Query(None, alias="object"),
) -> dict:
    column = dict(PROCEDURE_ROLES).get(role)
    if not column:
        raise HTTPException(status_code=404, detail="没有这个过程")
    folder, data, source = source_library(plant, command, create=True)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        ensure_objects(cursor, folder, data, plugin)
        target = select_object(data, object_id)
        metadata = find_metadata_by_id(cursor, str(target["id"]))
        name = resolve_procedure(column, metadata)
        if not name:
            raise HTTPException(status_code=404, detail=f"{command} 没有 {role}")
        cursor.execute("SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(%s)", (f"dbo.{name}",))
        found = cursor.fetchall()
        if not found:
            raise HTTPException(status_code=404, detail=f"库里没有 {name} 这个过程")
        definition = found[0]["definition"] or ""
        sync_plugin(data, plant, command, source, plugin, str((data["objects"] or [{}])[0].get("name") or ""))
    finally:
        connection.close()

    old = next((item for item in target.get("procedures", []) if item.get("role") == role), None)
    if old and str(old.get("file") or "") not in {"", f"{name}.sql"}:
        (folder / str(old.get("file"))).unlink(missing_ok=True)

    procedures = [item for item in target.get("procedures", []) if item.get("role") != role]
    procedures.append({"role": role, "name": name, "file": f"{name}.sql"})
    target["procedures"] = [
        next(item for item in procedures if item.get("role") == item_role)
        for item_role, _column in PROCEDURE_ROLES
        if any(item.get("role") == item_role for item in procedures)
    ]

    write_sql_file(folder / f"{name}.sql", definition)
    mark_pulled(target, role)
    write_object(folder, data)
    return function_pack(plant, command)


COMMENT_KEYWORD_NAMES = {"end", "null", "case", "else", "then", "when"}


def strip_sql_comments(text: str) -> str:
    kept: list[str] = []
    index = 0
    length = len(text)
    line_comment = False
    block_comment = False
    quoted = False
    while index < length:
        char = text[index]
        following = text[index + 1] if index + 1 < length else ""
        if line_comment:
            if char == "\n":
                line_comment = False
                kept.append(char)
        elif block_comment:
            if char == "*" and following == "/":
                block_comment = False
                index += 1
            elif char == "\n":
                kept.append(char)
        elif quoted:
            kept.append(char)
            if char == "'":
                if following == "'":
                    kept.append(following)
                    index += 1
                else:
                    quoted = False
        elif char == "-" and following == "-":
            line_comment = True
            index += 1
        elif char == "/" and following == "*":
            block_comment = True
            index += 1
        else:
            if char == "'":
                quoted = True
            kept.append(char)
        index += 1
    return "".join(kept)


def is_word_start(text: str, index: int) -> bool:
    if index <= 0:
        return True
    before = text[index - 1]
    return not (before.isalnum() or before in "_@#")


def select_lists(sql: str) -> list[str]:
    lists: list[str] = []
    index = 0
    length = len(sql)
    depth = 0
    quoted = False
    bracketed = False
    while index < length:
        char = sql[index]
        if quoted:
            if char == "'":
                if index + 1 < length and sql[index + 1] == "'":
                    index += 1
                else:
                    quoted = False
        elif bracketed:
            if char == "]":
                bracketed = False
        elif char == "'":
            quoted = True
        elif char == "[":
            bracketed = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth = max(0, depth - 1)
        elif depth == 0 and sql[index:index + 6].lower() == "select" and is_word_start(sql, index):
            cursor = index + 6
            inner = 0
            in_quote = False
            in_bracket = False
            while cursor < length:
                current = sql[cursor]
                if in_quote:
                    if current == "'":
                        if cursor + 1 < length and sql[cursor + 1] == "'":
                            cursor += 1
                        else:
                            in_quote = False
                elif in_bracket:
                    if current == "]":
                        in_bracket = False
                elif current == "'":
                    in_quote = True
                elif current == "[":
                    in_bracket = True
                elif current == "(":
                    inner += 1
                elif current == ")":
                    inner = max(0, inner - 1)
                elif inner == 0 and sql[cursor:cursor + 4].lower() == "from" and is_word_start(sql, cursor):
                    lists.append(sql[index + 6:cursor])
                    break
                cursor += 1
            index = cursor
            continue
        index += 1
    return lists


def split_select_items(segment: str) -> list[str]:
    items: list[str] = []
    index = 0
    depth = 0
    quoted = False
    bracketed = False
    start = 0
    while index < len(segment):
        char = segment[index]
        if quoted:
            if char == "'":
                if index + 1 < len(segment) and segment[index + 1] == "'":
                    index += 1
                else:
                    quoted = False
        elif bracketed:
            if char == "]":
                bracketed = False
        elif char == "'":
            quoted = True
        elif char == "[":
            bracketed = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth = max(0, depth - 1)
        elif char == "," and depth == 0:
            items.append(segment[start:index].strip())
            start = index + 1
        index += 1
    items.append(segment[start:].strip())
    return [item for item in items if item]


def select_item_name(item: str) -> str:
    text = item.strip()
    if not text or text == "*":
        return ""
    aliased = re.search(r"\bAS\s+(\[[^\]]+\]|'[^']+'|\"[^\"]+\"|[A-Za-z_][A-Za-z0-9_]*)\s*$", text, re.IGNORECASE)
    if aliased:
        return aliased.group(1).strip("[]'\"")
    trailing = re.search(r"(?:^|\s)(\[[^\]]+\]|'[^']+'|\"[^\"]+\"|[A-Za-z_][A-Za-z0-9_]*)\s*$", text)
    if trailing:
        name = trailing.group(1).strip("[]'\"")
        return "" if name.lower() in COMMENT_KEYWORD_NAMES else name
    column = re.search(r"\.(\[[^\]]+\]|[A-Za-z_][A-Za-z0-9_]*)\s*$", text)
    if column:
        return column.group(1).strip("[]")
    return ""


def select_columns(definition: str) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for segment in select_lists(strip_sql_comments(definition)):
        for item in split_select_items(segment):
            name = select_item_name(item)
            key = name.lower()
            if name and key not in seen:
                seen.add(key)
                names.append(name)
    return names


def tree_view_columns(cursor, name: str) -> list[str]:
    if not re.fullmatch(r"[A-Za-z0-9_]+", name):
        raise HTTPException(status_code=404, detail="TreeView 过程名不合法")
    try:
        cursor.execute(
            "SELECT name, error_number FROM sys.dm_exec_describe_first_result_set_for_object(OBJECT_ID(%s), 0)",
            (f"dbo.{name}",),
        )
        columns = [str(row.get("name")) for row in cursor.fetchall() if row.get("name")]
        if columns:
            return columns
    except Exception:
        try:
            cursor.connection.rollback()
        except Exception:
            pass
    cursor.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(%s)) AS definition", (f"dbo.{name}",))
    row = cursor.fetchone() or {}
    return select_columns(str(row.get("definition") or ""))


def column_texts(cursor, columns: list[str]) -> list[dict]:
    translated = translate_texts(cursor, columns)
    return [{"name": name, "text": translated.get(name, "")} for name in columns]


@app.get("/api/functions/{plant}/{command}/tree-columns")
def tree_columns(plant: str, command: str, object_id: str | None = Query(None, alias="object")) -> dict:
    folder, data, source = source_library(plant, command)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        ensure_objects(cursor, folder, data, plugin)
        target = select_object(data, object_id)
        metadata = find_metadata_by_id(cursor, str(target["id"]))
        name = resolve_procedure("TreeView", metadata)
        if not name:
            raise HTTPException(status_code=404, detail=f"{command} 没有 TreeView")
        columns = column_texts(cursor, tree_view_columns(cursor, name))
    finally:
        connection.close()
    return {"name": name, "columns": columns}


def is_multiline(type_text: str) -> bool:
    name = str(type_text or "").lower()
    return name in {"text", "ntext"} or name.endswith("(max)")


def table_types(cursor, metadata: dict) -> dict[str, str]:
    if not str(metadata.get("ObjectId") or "").strip():
        return {}
    table = metadata_table_name(cursor, metadata)
    cursor.execute(
        "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE "
        "FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = %s",
        (table,),
    )
    return {
        str(row["COLUMN_NAME"]).lower(): sql_type(
            row["DATA_TYPE"],
            row["CHARACTER_MAXIMUM_LENGTH"],
            row["NUMERIC_PRECISION"],
            row["NUMERIC_SCALE"],
        )
        for row in cursor.fetchall()
    }


def main_view_document(cursor, metadata: dict) -> dict:
    metadata_id = str(metadata.get("MetadataId") or "").strip()

    cursor.execute(
        "SELECT RTRIM(MetadataFieldGroupId) AS id, FieldGroupSequence, FieldGroupName, ColumnCount, "
        "FieldGroupHeight, IsCollapsed, IsHidden "
        "FROM dbo.SysMetadataFieldGroup WITH (NOLOCK) WHERE RTRIM(MetadataId) = %s "
        "ORDER BY FieldGroupSequence",
        (metadata_id,),
    )
    groups = cursor.fetchall()
    group_ids = [str(group["id"]) for group in groups]
    fields: list[dict] = []
    methods: list[dict] = []
    if group_ids:
        marks = ", ".join(["%s"] * len(group_ids))
        cursor.execute(
            "SELECT RTRIM(MetadataFieldId) AS id, RTRIM(MetadataFieldGroupId) AS group_id, FieldName, "
            "ControlLine, IsHidden, IsReadOnly, IsMustInput, IsValueListUsage, ValueList, ValueListFilterField "
            "FROM dbo.SysMetadataField WITH (NOLOCK) "
            f"WHERE RTRIM(MetadataFieldGroupId) IN ({marks}) ORDER BY MetadataFieldId",
            tuple(group_ids),
        )
        fields = cursor.fetchall()
        cursor.execute(
            "SELECT RTRIM(MetadataMethodId) AS id, RTRIM(MetadataFieldGroupId) AS group_id, "
            "MethodSequence, MethodName, SQLDoMethod, IsBeforeRunningConfirm, PromptMessage, "
            "IsRefreshTreeView, IsAcceptMainViewAsParameter, MainViewParameter, AccessCode, IsPrintMethod "
            "FROM dbo.SysMetadataMethod WITH (NOLOCK) "
            f"WHERE RTRIM(MetadataFieldGroupId) IN ({marks}) "
            "ORDER BY MethodSequence, MetadataMethodId",
            tuple(group_ids),
        )
        methods = cursor.fetchall()

    types = table_types(cursor, metadata)
    names = (
        [group.get("FieldGroupName") for group in groups]
        + [field.get("FieldName") for field in fields]
        + [method.get("MethodName") for method in methods]
    )
    texts = translate_texts(cursor, names)

    order: dict[str, int] = {}
    main_name = resolve_procedure("MainView", metadata)
    if main_name:
        for index, column in enumerate(tree_view_columns(cursor, main_name)):
            order.setdefault(str(column).lower(), index)

    by_group: dict[str, list[dict]] = {}
    for field in fields:
        name = str(field.get("FieldName") or "")
        type_text = types.get(name.lower(), "")
        lines = field.get("ControlLine")
        lines = int(lines) if lines not in (None, "") else 0
        by_group.setdefault(str(field.get("group_id")), []).append(
            {
                "id": field["id"],
                "name": name,
                "text": texts.get(name, ""),
                "type": type_text,
                "lines": lines,
                "multiline": is_multiline(type_text) or lines > 0,
                "hidden": bool(field.get("IsHidden")),
                "readonly": bool(field.get("IsReadOnly")),
                "required": bool(field.get("IsMustInput")),
                "valueList": bool(field.get("IsValueListUsage")),
                "valueListName": str(field.get("ValueList") or "").strip(),
                "valueListFilter": str(field.get("ValueListFilterField") or "").strip(),
            }
        )
    for items in by_group.values():
        items.sort(key=lambda item: order.get(item["name"].lower(), len(order)))

    by_group_methods: dict[str, list[dict]] = {}
    for method in methods:
        name = str(method.get("MethodName") or "")
        by_group_methods.setdefault(str(method.get("group_id")), []).append(
            {
                "id": method["id"],
                "sequence": str(method.get("MethodSequence") or "").strip(),
                "name": name,
                "text": texts.get(name, ""),
                "sql": str(method.get("SQLDoMethod") or "").strip(),
                "confirm": bool(method.get("IsBeforeRunningConfirm")),
                "prompt": str(method.get("PromptMessage") or "").strip(),
                "refreshTree": bool(method.get("IsRefreshTreeView")),
                "acceptMainView": bool(method.get("IsAcceptMainViewAsParameter")),
                "mainViewParameter": str(method.get("MainViewParameter") or "").strip(),
                "accessCode": str(method.get("AccessCode") or "").strip(),
                "print": bool(method.get("IsPrintMethod")),
            }
        )

    return {
        "name": str(metadata.get("MetadataName") or ""),
        "groups": [
            {
                "id": group["id"],
                "sequence": str(group.get("FieldGroupSequence") or "").strip(),
                "name": str(group.get("FieldGroupName") or ""),
                "text": texts.get(str(group.get("FieldGroupName") or ""), ""),
                "columns": int(group.get("ColumnCount") or 1),
                "height": group.get("FieldGroupHeight"),
                "collapsed": bool(group.get("IsCollapsed")),
                "hidden": bool(group.get("IsHidden")),
                "fields": by_group.get(str(group["id"]), []),
                "methods": by_group_methods.get(str(group["id"]), []),
            }
            for group in groups
        ],
    }


@app.get("/api/functions/{plant}/{command}/main-view")
def main_view(plant: str, command: str, object_id: str | None = Query(None, alias="object")) -> dict:
    folder, data, source = source_library(plant, command)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        ensure_objects(cursor, folder, data, plugin)
        target = select_object(data, object_id)
        metadata = find_metadata_by_id(cursor, str(target["id"]))
        document = main_view_document(cursor, metadata)
    finally:
        connection.close()
    return document


@app.post("/api/functions/{plant}/{command}/pull/style")
def pull_style(plant: str, command: str, object_id: str | None = Query(None, alias="object")) -> dict:
    folder, data, source = source_library(plant, command, create=True)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        ensure_objects(cursor, folder, data, plugin)
        target = select_object(data, object_id)
        metadata = find_metadata_by_id(cursor, str(target["id"]))
        tree_name = resolve_procedure("TreeView", metadata)
        tree = {"name": tree_name, "columns": []}
        if tree_name:
            tree["columns"] = column_texts(cursor, tree_view_columns(cursor, tree_name))
        style = {"tree": tree, "main": main_view_document(cursor, metadata)}
        for group in style["main"]["groups"]:
            for method in group.get("methods") or []:
                name = str(method.get("sql") or "").strip()
                definition = procedure_definition(cursor, name) if name else None
                file_name = ""
                if definition is not None:
                    file_name = f"{name}.sql"
                    write_sql_file(folder / file_name, definition)
                method["file"] = file_name
    finally:
        connection.close()

    target["style"] = style
    mark_pulled(target, "style")
    write_object(folder, data)
    output = {
        **style,
        "main": {
            **style["main"],
            "groups": [
                {
                    **group,
                    "methods": [
                        {
                            **method,
                            "definition": (
                                (folder / str(method.get("file") or "")).read_text(encoding="utf-8")
                                if re.fullmatch(r"[A-Za-z0-9_]+\.sql", str(method.get("file") or ""))
                                and (folder / str(method.get("file") or "")).is_file()
                                else ""
                            ),
                        }
                        for method in group.get("methods") or []
                    ],
                }
                for group in style["main"]["groups"]
            ],
        },
    }
    return output


def value_list_names(document: dict) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for group in document.get("groups") or []:
        if group.get("hidden"):
            continue
        for field in group.get("fields") or []:
            if field.get("hidden"):
                continue
            name = str(field.get("valueListName") or "").strip()
            if not field.get("valueList") or not name:
                continue
            key = name.lower()
            if key in seen:
                continue
            seen.add(key)
            names.append(name)
    return names


def procedure_definition(cursor, name: str) -> str | None:
    if not re.fullmatch(r"[A-Za-z0-9_]+", name):
        return None
    cursor.execute("SELECT definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(%s)", (f"dbo.{name}",))
    found = cursor.fetchall()
    if not found:
        return None
    return found[0]["definition"] or ""


@app.post("/api/functions/{plant}/{command}/pull/valuelists")
def pull_value_lists(plant: str, command: str, object_id: str | None = Query(None, alias="object")) -> dict:
    folder, data, source = source_library(plant, command, create=True)
    connection = open_database(source)
    try:
        cursor = connection.cursor(as_dict=True)
        plugin = find_plugin(cursor, command)
        ensure_objects(cursor, folder, data, plugin)
        target = select_object(data, object_id)
        metadata = find_metadata_by_id(cursor, str(target["id"]))
        document = main_view_document(cursor, metadata)
        entries = []
        for name in value_list_names(document):
            definition = procedure_definition(cursor, name)
            if definition is None:
                entries.append({"name": name, "file": "", "missing": True})
                continue
            file_name = f"{name}.sql"
            write_sql_file(folder / file_name, definition)
            entries.append({"name": name, "file": file_name, "missing": False})
        used_files = {str(entry.get("file") or "") for entry in entries}
        keep_files = {str(item.get("file") or "") for item in target.get("procedures") or []}
        for entry in target.get("valueLists") or []:
            file_name = str(entry.get("file") or "")
            if file_name and file_name not in used_files and file_name not in keep_files and re.fullmatch(r"[A-Za-z0-9_]+\.sql", file_name):
                (folder / file_name).unlink(missing_ok=True)
    finally:
        connection.close()

    target["valueLists"] = entries
    mark_pulled(target, "valueList")
    write_object(folder, data)
    return function_pack(plant, command)


@app.get("/api/health")
def health() -> dict:
    return {"ok": True}


@app.get("/api/workbench")
def workbench() -> dict:
    environments = []
    if CATALOG.is_dir():
        for path in sorted(CATALOG.iterdir()):
            if path.is_file() and not path.name.startswith("."):
                environments.append(environment(path.name, parse_catalog(path.read_text(encoding="utf-8"))))
    environments.sort(key=lambda item: item["order"])
    test = [item for item in environments if item["kind"] == "test"]
    prod = [item for item in environments if item["kind"] == "prod"]
    return {
        "name": "OrBit",
        "readonly": True,
        "agent": {**describe(), "guide": guide()},
        "layout": layout(),
        "skills": skills(),
        "counts": {"all": len(environments), "test": len(test), "prod": len(prod)},
        "test": test,
        "prod": prod,
    }
