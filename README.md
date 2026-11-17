# OrBit

MES / WMS 的 AI 工作台。页面看八套库，super-agent 接大模型，每个库单独连接。

## 目录

| 目录 | 作用 |
|---|---|
| `web/` | 工作台页面，`127.0.0.1:3000` |
| `server/` | Python 接口，`127.0.0.1:8765` |
| `agent/` | 大模型入口 |
| `super-agent/` | 对用户说的话 |
| `db/catalog/` | 八套库的目录 |
| `library/` | 工作台的功能元数据缓存，按库/功能存放 |
| `tasks/` | 任务交付物，按 `tasks/{库}/{类别}/{功能}/` 存放 |
| `secrets/` | 凭据，不入库 |
| `.AGENTS/skills/` | 给 Agent 的技能 |
| `scripts/` | 启动工作台 |

## 启动

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-workbench.ps1
```

打开 `http://127.0.0.1:3000`。

## SQL 语法检查

在功能详情的 SQL 阅读器中点击「语法检查」，或在右键菜单中选择同一项。工作台会在当前功能对应的数据源上使用 `SET PARSEONLY ON` 检查完整 SQL，然后关闭连接；只检查语法，不执行 SQL，也不校验表、字段等对象是否存在。

## 给 Agent

会话入口是 [AGENT.md](AGENT.md)。查库时读 `.AGENTS/skills/mes-db/SKILL.md`。

## Claude Code 查库 MCP

项目根目录的 `.mcp.json` 固定注册八套单库 MCP，Claude Code 会从项目根目录启动 `.venv/Scripts/python.exe`。首次在新环境使用时先安装依赖：

```powershell
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
```

然后重开 Claude Code 会话，或用 `/mcp` 检查连接。每个工具调用都会新建并关闭数据库连接；临时连接错误最多重试 3 次，存储过程执行不会自动重放。凭据只从 `secrets/{MCP名}.env` 读取，不写入 `.mcp.json`。
