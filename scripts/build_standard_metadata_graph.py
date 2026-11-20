"""从 MES 元数据库拉取标准元对象，并按表字段生成关联图。

产物：
- library/<plant>/standard-metadata.json          元对象、表字段与字段级引用明细
- server/fixtures/standard-metadata-graph.json    3D 功能逻辑页使用的节点和关系

关系规则：标准元对象 A 的表里存在字段 <X>Id，且标准元对象 B 的表名是 <X>，
并且该字段不是 A 自身表的主键，就建立 A --<X>Id--> B。
字段同名只代表引用约定，不代表数据库里存在外键约束。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from server import app

SQL_OBJECTS = """
SELECT RTRIM(p.PluginCommand) AS command,
       p.PluginName,
       p.PluginDescription,
       m.MetadataId,
       m.MetadataName,
       m.MetadataDescription,
       m.IsFullReadOnly,
       m.ObjectId,
       o.ObjectName,
       (SELECT TOP 1 tx.Text2 FROM dbo.SysText tx WITH (NOLOCK)
         WHERE tx.TextModule = m.MetadataName AND tx.TextOwner = N'[Public Text]') AS cn
FROM dbo.SysPlugIn p WITH (NOLOCK)
LEFT JOIN dbo.SysMetadata m WITH (NOLOCK) ON m.MetadataId = p.MetadataId
LEFT JOIN dbo.SysObject o WITH (NOLOCK) ON o.ObjectId = m.ObjectId
WHERE p.PluginFileName = 'Plugin Standard.dll'
ORDER BY RTRIM(p.PluginCommand)
"""

SQL_COLUMNS = """
SELECT c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE,
       c.CHARACTER_MAXIMUM_LENGTH, c.ORDINAL_POSITION, c.IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_SCHEMA = 'dbo'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION
"""

SQL_PRIMARY_KEYS = """
SELECT tb.name AS TableName, c.name AS ColumnName
FROM sys.tables tb
JOIN sys.indexes i ON i.object_id = tb.object_id AND i.is_primary_key = 1
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
"""

# 领域按关键词顺序判定，先匹配先得分。只用于图上的分组筛选。
DOMAIN_RULES = (
    ("equipment", "设备与治具", (
        "设备", "治具", "模具", "点检", "保养", "计量", "效验", "esd",
        "equipment", "asset", "gage", "upkeep", "repairlog", "spareparts",
    )),
    ("quality", "质量与检验", (
        "检验", "验货", "品质", "质量", "不良", "缺陷", "返修", "维修", "客验",
        "抽检", "报告", "失效", "分析", "aql", "oqa", "iqc", "spc", "defect",
        "repair", "inspection", "quality", "abnormal", "emr",
    )),
    ("warehouse", "仓储与物流", (
        "仓库", "库位", "库存", "入库", "出库", "盘点", "调拨", "发料", "领料",
        "备料", "退料", "交货", "出货", "送货", "发货", "收货", "点收", "上架",
        "装箱", "栈板", "合盘", "agv", "物流", "warehouse", "storage", "stock",
        "picking", "delivery", "ship", "pallet", "cell", "inventory",
    )),
    ("production", "生产与计划", (
        "工单", "订单", "计划", "排产", "生产", "派工", "报工", "烧录", "老化",
        "产能", "工序", "工艺", "产线", "线体", "bom", "mo", "order", "plan",
        "production", "capacity", "burn", "lot", "smt", "dip", "assy",
    )),
    ("material", "物料与产品", (
        "物料", "产品", "料号", "替代", "包装", "条码", "标签", "编码", "主数据",
        "material", "product", "item", "barcode", "label", "sn", "code",
    )),
    ("partner", "往来与购销", (
        "客户", "供应商", "采购", "销售", "报价", "询价", "custom", "vendor",
        "supplier", "purchase", "sale", "inquiry", "offer",
    )),
    ("organization", "组织与基础数据", (
        "企业", "工厂", "场地", "部门", "工作中心", "线别", "班次", "成本中心",
        "组织", "enterprise", "factory", "site", "division", "workcenter",
        "shift", "costcenter", "organization",
    )),
    ("system", "系统与平台", (
        "系统", "元对象", "菜单", "用户", "权限", "参数", "日志", "接口", "导入",
        "工作流", "消息", "备份", "查询", "sys", "metadata", "menu", "user",
        "parameter", "log", "interface", "workflow", "import", "query",
    )),
)


def split_words(value: str) -> str:
    """把 CamelCase / 缩写边界拆成空格，避免 esd 命中 MESDelivery 这类误判。"""
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value)
    text = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", text)
    return text.lower()


def classify_domain(node: dict) -> tuple[str, str]:
    text = " ".join(
        split_words(str(node.get(key) or ""))
        for key in ("label", "pluginName", "metadataName", "table")
    )
    for domain, label, keywords in DOMAIN_RULES:
        for keyword in keywords:
            if keyword.isascii():
                if re.search(rf"(?<![a-z0-9]){re.escape(keyword)}(?![a-z0-9])", text):
                    return domain, label
            elif keyword in text:
                return domain, label
    return "other", "其他"


def text_or(*values: str) -> str:
    for value in values:
        value = str(value or "").strip()
        if value:
            return value
    return ""


def build(env: str) -> tuple[dict, dict]:
    plant = env.split("-")[0]
    connection = app.open_database(env)
    try:
        cursor = connection.cursor(as_dict=True)
        cursor.execute(SQL_OBJECTS)
        plugin_rows = cursor.fetchall()
        cursor.execute(SQL_COLUMNS)
        column_rows = cursor.fetchall()
        cursor.execute(SQL_PRIMARY_KEYS)
        pk_rows = cursor.fetchall()
    finally:
        connection.close()

    columns_by_table: dict[str, list[dict]] = defaultdict(list)
    for row in column_rows:
        columns_by_table[str(row["TABLE_NAME"]).lower()].append(row)
    pk_by_table: dict[str, set[str]] = defaultdict(set)
    for row in pk_rows:
        pk_by_table[str(row["TableName"]).lower()].add(str(row["ColumnName"]).lower())

    groups: dict[str, list[dict]] = defaultdict(list)
    for row in plugin_rows:
        metadata_id = str(row.get("MetadataId") or "").strip()
        key = metadata_id or f"CMD:{str(row.get('command') or '').strip()}"
        groups[key].append(row)

    nodes: list[dict] = []
    node_by_table: dict[str, list[dict]] = defaultdict(list)
    for key, group in groups.items():
        head = sorted(group, key=lambda item: str(item.get("command") or "").strip())[0]
        commands = sorted({str(item.get("command") or "").strip() for item in group})
        metadata_name = str(head.get("MetadataName") or "").strip()
        table = str(head.get("ObjectName") or "").strip()
        cn = text_or(head.get("cn"), head.get("PluginName"), metadata_name)
        node = {
            "id": metadata_name or commands[0],
            "code": commands[0],
            "label": cn,
            "english": metadata_name or commands[0],
            "kind": "function",
            "role": "core",
            "plugin": "Plugin Standard.dll",
            "commands": commands,
            "pluginName": str(head.get("PluginName") or "").strip(),
            "metadataId": str(head.get("MetadataId") or "").strip(),
            "metadataName": metadata_name,
            "table": table,
            "description": text_or(
                head.get("MetadataDescription"),
                head.get("PluginDescription"),
                metadata_name,
                commands[0],
            ),
            "readOnly": bool(head.get("IsFullReadOnly")),
        }
        node["domain"], node["domainLabel"] = classify_domain(node)
        nodes.append(node)
        if table:
            node_by_table[table.lower()].append(node)

    # 节点标识兜底去重：极少数元对象名可能重复。
    seen_ids: Counter[str] = Counter()
    for node in nodes:
        seen_ids[node["id"]] += 1
        if seen_ids[node["id"]] > 1:
            node["id"] = f"{node['id']}:{node['code']}"

    node_by_id = {node["id"]: node for node in nodes}
    for node in nodes:
        table = node["table"]
        if not table:
            node["columns"] = []
            continue
        key = table.lower()
        pk_columns = pk_by_table.get(key) or {f"{key}id"}
        columns = []
        for row in columns_by_table.get(key, []):
            name = str(row["COLUMN_NAME"])
            columns.append({
                "name": name,
                "type": str(row["DATA_TYPE"]),
                "length": row["CHARACTER_MAXIMUM_LENGTH"],
                "nullable": str(row["IS_NULLABLE"]).upper() == "YES",
                "primaryKey": name.lower() in pk_columns,
            })
        node["columns"] = columns

    links: list[dict] = []
    link_ids: set[str] = set()
    unresolved = Counter()
    ambiguous: list[dict] = []
    for node in sorted(nodes, key=lambda item: item["id"]):
        table = node["table"].lower()
        if not table:
            continue
        pk_columns = pk_by_table.get(table) or {f"{table}id"}
        for column in node["columns"]:
            name = column["name"]
            lower = name.lower()
            if lower in pk_columns or not lower.endswith("id") or lower == "id":
                continue
            prefix = lower[:-2]
            candidates = [
                target
                for target in node_by_table.get(prefix, [])
                if target["id"] != node["id"]
            ]
            match_kind = "exact"
            if not candidates:
                # 后缀匹配：ToWorkcenterId、PurchaseUOMId 这类限定词前缀。
                suffix_table = ""
                for table_key in node_by_table:
                    if (
                        len(table_key) >= 3
                        and table_key.isalnum()
                        and len(table_key) > len(suffix_table)
                        and prefix.endswith(table_key)
                    ):
                        suffix_table = table_key
                if suffix_table:
                    candidates = [
                        target
                        for target in node_by_table[suffix_table]
                        if target["id"] != node["id"]
                    ]
                    match_kind = "suffix"
            if not candidates:
                unresolved[prefix] += 1
                continue
            if len(candidates) > 1 and match_kind == "suffix":
                canonical = [t for t in candidates if t["table"].lower() == candidates[0]["table"].lower()]
                target = sorted(canonical, key=lambda t: len(t["english"]))[0]
            elif len(candidates) > 1:
                exact = [t for t in candidates if t["english"].lower() == prefix]
                if len(exact) == 1:
                    target = exact[0]
                else:
                    canonical = [t for t in candidates if t["table"].lower() == prefix]
                    if len(canonical) == 1:
                        target = canonical[0]
                    else:
                        ambiguous.append({
                            "source": node["id"],
                            "column": name,
                            "candidates": [t["id"] for t in candidates],
                        })
                        continue
            else:
                target = candidates[0]

            link_id = f"{node['id']}>{name}>{target['id']}"
            if link_id in link_ids:
                continue
            link_ids.add(link_id)
            target_pk_types = [
                c["type"] for c in target["columns"] if c["primaryKey"]
            ]
            if not target_pk_types:
                target_pk_types = [
                    c["type"]
                    for c in target["columns"]
                    if c["name"].lower() == target["table"].lower() + "id"
                ]
            same_type = column["type"] in target_pk_types
            if match_kind == "suffix":
                certainty = "字段名后缀引用"
            else:
                certainty = "字段同名引用" if same_type else "字段名匹配"
            links.append({
                "id": link_id,
                "source": node["id"],
                "target": target["id"],
                "type": "field",
                "relation": name,
                "field": name,
                "fieldType": column["type"],
                "certainty": certainty,
            })

    domain_labels = {domain: label for domain, label, _ in DOMAIN_RULES}
    domain_labels["other"] = "其他"
    domain_counts = Counter(node["domain"] for node in nodes)
    unresolved_top = [
        {"prefix": prefix, "count": count}
        for prefix, count in unresolved.most_common(60)
    ]

    generated_at = datetime.now().astimezone().isoformat(timespec="seconds")
    graph = {
        "meta": {
            "title": f"{plant} 标准元对象关联图",
            "scope": "standard-metadata",
            "readOnly": True,
            "source": env,
            "generatedAt": generated_at,
            "functionCount": len(nodes),
            "commandCount": len(plugin_rows),
            "nodeCount": len(nodes),
            "linkCount": len(links),
            "method": (
                "节点是去重后的标准元对象（Plugin Standard.dll）。"
                "关系来自表字段：表字段名 <X>Id 指向表名为 <X> 的另一标准元对象，"
                "且该字段不是本表主键。"
            ),
            "caution": (
                "字段同名只说明 MES 的引用约定，不代表数据库里存在外键约束。"
                "共用同一张表的多个元对象节点会各自带出相同字段关系。"
            ),
            "domains": [
                {"id": domain, "label": label, "count": domain_counts.get(domain, 0)}
                for domain, label in (
                    ("organization", domain_labels["organization"]),
                    ("material", domain_labels["material"]),
                    ("production", domain_labels["production"]),
                    ("quality", domain_labels["quality"]),
                    ("equipment", domain_labels["equipment"]),
                    ("warehouse", domain_labels["warehouse"]),
                    ("partner", domain_labels["partner"]),
                    ("system", domain_labels["system"]),
                    ("other", domain_labels["other"]),
                )
            ],
            "unresolved": unresolved_top,
            "ambiguous": ambiguous[:200],
        },
        "nodes": [
            {k: v for k, v in node.items() if k != "columns"} | {
                "columnCount": len(node.get("columns") or [])
            }
            for node in nodes
        ],
        "links": links,
    }

    references_out: dict[str, list[dict]] = defaultdict(list)
    references_in: dict[str, list[dict]] = defaultdict(list)
    for link in links:
        references_out[link["source"]].append({
            "target": link["target"],
            "field": link["field"],
            "certainty": link["certainty"],
        })
        references_in[link["target"]].append({
            "source": link["source"],
            "field": link["field"],
            "certainty": link["certainty"],
        })

    data = {
        "plant": plant,
        "source": env,
        "pulledAt": generated_at,
        "pluginFile": "Plugin Standard.dll",
        "objectCount": len(nodes),
        "commandCount": len(plugin_rows),
        "method": (
            "references 表示本对象表里的字段指向别的标准元对象；"
            "referencedBy 表示别的对象用哪个字段指向本对象。"
            "字段同名只代表引用约定，不代表数据库外键约束。"
        ),
        "objects": [
            {
                "id": node["id"],
                "code": node["code"],
                "name": node["label"],
                "english": node["english"],
                "metadataId": node["metadataId"],
                "commands": node["commands"],
                "pluginName": node["pluginName"],
                "table": node["table"],
                "domain": node["domain"],
                "domainLabel": node["domainLabel"],
                "readOnly": node["readOnly"],
                "columns": node["columns"],
                "references": sorted(
                    references_out.get(node["id"], []),
                    key=lambda item: (item["field"], item["target"]),
                ),
                "referencedBy": sorted(
                    references_in.get(node["id"], []),
                    key=lambda item: (item["field"], item["source"]),
                ),
            }
            for node in sorted(nodes, key=lambda item: item["code"])
        ],
    }
    return graph, data


def main() -> None:
    parser = argparse.ArgumentParser(description="生成标准元对象字段关联图")
    parser.add_argument("--env", default="jiban-mes-prod")
    parser.add_argument(
        "--graph",
        default="",
        help="图文件路径，默认 server/fixtures/standard-metadata-graph.json",
    )
    parser.add_argument(
        "--data",
        default="",
        help="明细文件路径，默认 library/<plant>/standard-metadata.json",
    )
    args = parser.parse_args()

    plant = args.env.split("-")[0]
    graph_path = Path(args.graph) if args.graph else ROOT / "server" / "fixtures" / "standard-metadata-graph.json"
    data_path = Path(args.data) if args.data else ROOT / "library" / plant / "standard-metadata.json"

    graph, data = build(args.env)
    graph_path.parent.mkdir(parents=True, exist_ok=True)
    data_path.parent.mkdir(parents=True, exist_ok=True)
    graph_path.write_text(
        json.dumps(graph, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    data_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    meta = graph["meta"]
    print(f"环境 {args.env}：命令 {meta['commandCount']} 条，元对象 {meta['nodeCount']} 个，关系 {meta['linkCount']} 条")
    for item in meta["domains"]:
        print(f"  {item['label']}: {item['count']}")
    print(f"图文件 {graph_path}")
    print(f"明细文件 {data_path}")


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except AttributeError:
        pass
    main()
