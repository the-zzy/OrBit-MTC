# OrBit

MES / WMS 的 AI 工作台。页面看七套库，super-agent 接大模型，每个库单独连接。

## 目录

| 目录 | 作用 |
|---|---|
| `web/` | 工作台页面，`127.0.0.1:3000` |
| `server/` | Python 接口，`127.0.0.1:8765` |
| `agent/` | 大模型入口 |
| `super-agent/` | 对用户说的话 |
| `db/catalog/` | 七套库的目录 |
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
