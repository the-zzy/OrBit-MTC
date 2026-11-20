"""本地标准元对象字段关联图。只读接口不允许前端修改节点或关系。"""

from __future__ import annotations

import json
from pathlib import Path

from fastapi import APIRouter, HTTPException

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "standard-metadata-graph.json"
router = APIRouter(prefix="/api/memory", tags=["memory-graph"])


def load_graph() -> dict:
    try:
        document = json.loads(FIXTURE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=500, detail="功能逻辑测试数据读取失败") from exc

    nodes = document.get("nodes")
    links = document.get("links")
    if not isinstance(nodes, list) or not isinstance(links, list):
        raise HTTPException(status_code=500, detail="功能逻辑测试数据格式不正确")

    node_ids = {node.get("id") for node in nodes}
    if len(node_ids) != len(nodes) or None in node_ids:
        raise HTTPException(status_code=500, detail="功能逻辑节点标识无效")
    if any(link.get("source") not in node_ids or link.get("target") not in node_ids for link in links):
        raise HTTPException(status_code=500, detail="功能逻辑关系引用了不存在的节点")
    return document


@router.get("/graph")
def memory_graph() -> dict:
    """返回本地测试图的节点和关系，后续可由 Neo4j 只读查询替换数据源。"""
    return load_graph()


@router.get("/nodes/{node_id}")
def memory_node(node_id: str) -> dict:
    document = load_graph()
    node = next((item for item in document["nodes"] if item["id"] == node_id), None)
    if node is None:
        raise HTTPException(status_code=404, detail="功能逻辑节点不存在")
    links = [
        link
        for link in document["links"]
        if link["source"] == node_id or link["target"] == node_id
    ]
    return {"node": node, "links": links, "readOnly": True}
