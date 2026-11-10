"""大模型入口。凭据只在真正调用时读取，状态里不带密钥。"""

from __future__ import annotations

import json
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / "secrets" / "llm.env"
GUIDE_DIR = ROOT / "super-agent"


def load_config() -> dict[str, str]:
    if not ENV_FILE.is_file():
        return {}
    values: dict[str, str] = {}
    for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, raw = line.split("=", 1)
        values[key.strip()] = raw.strip().strip("'\"")
    return values


def describe() -> dict[str, str | bool]:
    config = load_config()
    model = config.get("LLM_MODEL", "")
    ready = bool(config.get("LLM_BASE_URL") and config.get("LLM_API_KEY") and model)
    return {
        "name": "super-agent",
        "ready": ready,
        "model": model if ready else "",
        "note": model if ready else "还没接入大模型",
    }


def guide() -> str:
    if not GUIDE_DIR.is_dir():
        return ""
    parts = [path.read_text(encoding="utf-8").strip() for path in sorted(GUIDE_DIR.glob("*.md"))]
    return "\n\n".join(part for part in parts if part)


def complete(messages: list[dict[str, str]]) -> str:
    config = load_config()
    text = guide()
    if text:
        messages = [{"role": "system", "content": text}, *messages]
    base = config.get("LLM_BASE_URL", "").rstrip("/")
    key = config.get("LLM_API_KEY", "")
    model = config.get("LLM_MODEL", "")
    if not base or not key or not model:
        raise RuntimeError("大模型还没接入")
    body = json.dumps({"model": model, "messages": messages}, ensure_ascii=False).encode("utf-8")
    request = Request(
        f"{base}/chat/completions",
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlopen(request, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        raise RuntimeError(f"大模型返回 {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError("大模型连不上") from exc
    return payload["choices"][0]["message"]["content"]
