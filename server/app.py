"""工作台后端。目录给页面看，大模型调用走 agent。"""

from __future__ import annotations

import sys
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from agent.llm import describe, guide
CATALOG = ROOT / "db" / "catalog"
SKILLS = ROOT / ".cursor" / "skills"
LAYOUT = (
    ("web", "工作台页面"),
    ("server", "接口"),
    ("agent", "大模型"),
    ("db", "数据库目录"),
    (".AGENTS", "管家说明"),
    (".cursor/skills", "技能"),
    ("secrets", "凭据"),
    ("scripts", "启动"),
    ("AGENT.md", "会话入口"),
    ("README.md", "项目说明"),
)

app = FastAPI(title="OrBit 工作台")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:3000", "http://localhost:3000"],
    allow_methods=["GET"],
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


def skills() -> list[dict]:
    found = []
    if not SKILLS.is_dir():
        return found
    for folder in sorted(path for path in SKILLS.iterdir() if path.is_dir()):
        page = folder / "SKILL.md"
        name, description = skill_text(page.read_text(encoding="utf-8")) if page.is_file() else ("", "")
        found.append({"id": folder.name, "name": name or folder.name, "description": description})
    return found


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
