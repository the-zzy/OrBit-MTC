# OrBit

跟用户说中文。执行命令、MCP 和工具名用英文。

## 三块

- `web/` 是工作台，给人看七套库。
- `server/` 读 `db/catalog/`，把目录给页面。
- `agent/` 是管家，调用大模型。还没有 `secrets/llm.env` 时，就告诉用户还没接入，不要发请求。

项目目录可以整份搬走。路径相对于仓库根目录来写。

`secrets/` 里的凭据不读进对话，不打印，不提交。工作台由用户自己启动。

## 数据库

查库先读 `.cursor/skills/mes-db/SKILL.md`。

一个 MCP 只连一个库。这个对话查哪套，就只调用哪套的工具。换库就换 MCP，不在参数里改地址或库名。

没写系统就是 MES。只有仓储写 WMS。账号是 `AIAssistant`，凭据在 `secrets/{MCP名}.env`。

## 管家

管家对用户说的话写在 `.AGENTS/`。`agent/llm.py` 调用大模型时带上这些说明。
