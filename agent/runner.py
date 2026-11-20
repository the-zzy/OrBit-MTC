"""浏览器版 Agent：用无头 Claude Code 跑一个完整回合，逐条事件吐给页面。

不读 secrets 里的密钥内容，只把它交给子进程的环境变量。
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
import time
from collections.abc import Iterator
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = ROOT / "secrets" / "llm.env"
MCP_FILE = ROOT / ".mcp.json"

MODES = {
    "readonly": {
        "label": "只读",
        "note": "能读仓库、查八套库，不改文件、不执行命令",
    },
}

# 工作台是给别人用的，只开放只读。要改文件或执行命令请用 VSCode / 终端。
ALLOWED_MODES = ("readonly",)

READ_TOOLS = ["Read", "Grep", "Glob", "TodoWrite"]
EDIT_TOOLS = [*READ_TOOLS, "Write", "Edit", "NotebookEdit"]
DENY_ALWAYS = ["Read(./secrets/**)", "Read(**/secrets/**)"]
_run_lock = threading.Lock()


class AgentError(RuntimeError):
    """给页面看的错误。"""


def _load_config() -> dict[str, str]:
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


def _cli_path() -> str | None:
    for name in ("claude.cmd", "claude.exe", "claude"):
        found = shutil.which(name)
        if found:
            return found
    fallback = Path("E:/soft/npm-global/claude.cmd")
    return str(fallback) if fallback.is_file() else None


def _mcp_servers() -> list[str]:
    try:
        data = json.loads(MCP_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    return sorted((data.get("mcpServers") or {}).keys())


def describe() -> dict:
    config = _load_config()
    ready = bool(config.get("LLM_BASE_URL") and config.get("LLM_API_KEY") and config.get("LLM_MODEL"))
    return {
        "ready": ready and _cli_path() is not None,
        "model": config.get("LLM_MODEL", "") if ready else "",
        "cli": _cli_path() or "",
        "modes": [{"id": key, **value} for key, value in MODES.items() if key in ALLOWED_MODES],
        "servers": _mcp_servers(),
    }


def _allowed_tools(mode: str) -> list[str]:
    base = EDIT_TOOLS if mode == "edit" else READ_TOOLS
    tools = list(base)
    for server in _mcp_servers():
        tools.append(f"mcp__{server}__query")
        if mode == "readonly":
            for extra in ("procedure", "list_tables", "describe_table"):
                tools.append(f"mcp__{server}__{extra}")
    return tools


def _build_env() -> dict[str, str]:
    config = _load_config()
    base, key, model = config.get("LLM_BASE_URL", ""), config.get("LLM_API_KEY", ""), config.get("LLM_MODEL", "")
    if not base or not key or not model:
        raise AgentError("还没接入大模型")
    env = dict(os.environ)
    env.update(
        {
            "ANTHROPIC_BASE_URL": base,
            "ANTHROPIC_AUTH_TOKEN": key,
            "ANTHROPIC_MODEL": model,
            "ANTHROPIC_SMALL_FAST_MODEL": config.get("LLM_SMALL_MODEL", model),
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
        }
    )
    return env


def _command(mode: str, session_id: str) -> list[str]:
    cli = _cli_path()
    if not cli:
        raise AgentError("找不到 claude 命令")
    args = [
        cli,
        "-p",
        "--output-format",
        "stream-json",
        "--verbose",
        "--include-partial-messages",
        "--max-turns",
        "40",
        "--permission-mode",
        "default",
    ]
    if mode == "full":
        args += ["--dangerously-skip-permissions"]
    else:
        args += ["--allowedTools", ",".join(_allowed_tools(mode))]
        args += ["--disallowedTools", ",".join(DENY_ALWAYS + ["Bash", "Task"])]
    if session_id:
        args += ["--resume", session_id]
    return args


def _tool_result_text(block: dict) -> str:
    content = block.get("content")
    if isinstance(content, str):
        return content
    parts: list[str] = []
    for item in content or []:
        if not isinstance(item, dict):
            continue
        if item.get("type") == "text":
            parts.append(str(item.get("text", "")))
    return "\n".join(parts)


def stream(prompt: str, mode: str = "readonly", session_id: str = "") -> Iterator[dict]:
    """跑一个回合，逐条产出事件。"""
    if not prompt.strip():
        raise AgentError("请输入问题")
    if mode not in ALLOWED_MODES:
        raise AgentError("工作台只允许只读模式")
    if not _run_lock.acquire(blocking=False):
        raise AgentError("上一个回合还没结束，请稍等")
    process = None
    try:
        command = _command(mode, session_id)
        env = _build_env()
        process = subprocess.Popen(
            command,
            cwd=str(ROOT),
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        assert process.stdin and process.stdout
        process.stdin.write(prompt.encode("utf-8"))
        process.stdin.close()

        saw_delta = False
        answered = False
        block_types: dict[int, str] = {}
        thinking_start = 0.0
        for raw in process.stdout:
            line = raw.decode("utf-8", errors="replace").strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = event.get("type")

            if kind == "system" and event.get("subtype") == "init":
                yield {"type": "meta", "sessionId": event.get("session_id", ""), "model": event.get("model", "")}
            elif kind == "stream_event":
                inner = event.get("event") or {}
                inner_type = inner.get("type")
                index = inner.get("index", 0)
                if inner_type == "content_block_start":
                    saw_delta = False
                    block = inner.get("content_block") or {}
                    block_types[index] = block.get("type", "")
                    if block.get("type") == "thinking":
                        thinking_start = time.monotonic()
                        yield {"type": "thinking_start"}
                elif inner_type == "content_block_stop":
                    if block_types.get(index) == "thinking":
                        yield {"type": "thinking_done", "ms": int((time.monotonic() - thinking_start) * 1000)}
                delta = inner.get("delta") or {}
                if delta.get("type") == "thinking_delta" and delta.get("thinking"):
                    yield {"type": "thinking_delta", "text": delta["thinking"]}
                elif delta.get("type") == "text_delta" and delta.get("text"):
                    saw_delta = True
                    answered = True
                    yield {"type": "text", "text": delta["text"]}
            elif kind == "assistant":
                for block in (event.get("message") or {}).get("content") or []:
                    if block.get("type") == "text" and block.get("text") and not saw_delta:
                        answered = True
                        yield {"type": "text", "text": block["text"]}
                    elif block.get("type") == "tool_use":
                        yield {
                            "type": "tool",
                            "id": block.get("id", ""),
                            "name": block.get("name", ""),
                            "input": block.get("input") or {},
                        }
            elif kind == "user":
                for block in (event.get("message") or {}).get("content") or []:
                    if block.get("type") == "tool_result":
                        yield {
                            "type": "tool_result",
                            "id": block.get("tool_use_id", ""),
                            "isError": bool(block.get("is_error")),
                            "text": _tool_result_text(block)[:20000],
                        }
            elif kind == "result":
                yield {
                    "type": "done",
                    "sessionId": event.get("session_id", "") or session_id,
                    "turns": event.get("num_turns", 0),
                    "durationMs": event.get("duration_ms", 0),
                    "costUsd": event.get("total_cost_usd", 0),
                    "isError": bool(event.get("is_error")) or event.get("subtype") not in (None, "success"),
                    "subtype": event.get("subtype", ""),
                }
                if not answered and isinstance(event.get("result"), str) and event["result"].strip():
                    yield {"type": "text", "text": event["result"].strip()}
        process.wait(timeout=30)
        err = (process.stderr.read() or b"").decode("utf-8", errors="replace").strip()
        if process.returncode and err:
            yield {"type": "error", "message": err.splitlines()[-1][:300]}
    except FileNotFoundError as exc:
        raise AgentError("找不到 claude 命令") from exc
    finally:
        if process and process.poll() is None:
            process.terminate()
        _run_lock.release()
