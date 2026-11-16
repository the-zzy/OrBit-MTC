"""大模型入口。凭据只在真正调用时读取，状态里不带密钥。"""

from __future__ import annotations

import json
from collections.abc import Iterator
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


def _request_parts(messages: list[dict[str, str]]) -> tuple[str, dict, str, dict]:
    config = load_config()
    text = guide()
    if text:
        messages = [{"role": "system", "content": text}, *messages]
    base = config.get("LLM_BASE_URL", "").rstrip("/")
    key = config.get("LLM_API_KEY", "")
    model = config.get("LLM_MODEL", "")
    if not base or not key or not model:
        raise RuntimeError("大模型还没接入")

    protocol = config.get("LLM_PROTOCOL", "openai").strip().lower()
    if protocol == "anthropic":
        system = "\n\n".join(item["content"] for item in messages if item["role"] == "system")
        body = {
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "messages": [item for item in messages if item["role"] != "system"],
        }
        endpoint = f"{base}/v1/messages"
        headers = {
            "Authorization": f"Bearer {key}",
            "x-api-key": key,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json",
        }
    else:
        body = {"model": model, "messages": messages, "max_tokens": 4096}
        endpoint = f"{base}/chat/completions"
        headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    return protocol, body, endpoint, headers


def complete(messages: list[dict[str, str]]) -> str:
    protocol, body, endpoint, headers = _request_parts(messages)

    request = Request(
        endpoint,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urlopen(request, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        raise RuntimeError(f"大模型返回 {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError("大模型连不上") from exc
    if protocol == "anthropic":
        return "\n".join(item.get("text", "") for item in payload.get("content", []) if item.get("type") == "text").strip()
    return payload["choices"][0]["message"]["content"]


def stream(messages: list[dict[str, str]]) -> Iterator[str]:
    """流式补全，逐段产出文本增量。出错时抛 RuntimeError。"""
    protocol, body, endpoint, headers = _request_parts(messages)
    body["stream"] = True

    request = Request(
        endpoint,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        response = urlopen(request, timeout=60)
    except HTTPError as exc:
        raise RuntimeError(f"大模型返回 {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError("大模型连不上") from exc

    with response:
        for raw in response:
            line = raw.decode("utf-8", errors="replace").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if not data or data == "[DONE]":
                continue
            try:
                event = json.loads(data)
            except json.JSONDecodeError:
                continue
            if protocol == "anthropic":
                kind = event.get("type", "")
                if kind == "content_block_delta":
                    delta = event.get("delta", {})
                    if delta.get("type") == "text_delta":
                        text = delta.get("text", "")
                        if text:
                            yield text
                elif kind == "error":
                    message = event.get("error", {}).get("message", "未知错误")
                    raise RuntimeError(f"大模型出错：{message}")
            else:
                for choice in event.get("choices", []):
                    text = choice.get("delta", {}).get("content") or ""
                    if text:
                        yield text
