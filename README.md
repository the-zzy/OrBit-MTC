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

打开 `http://127.0.0.1:3000`，先登录工作台。

多个账号写在 `secrets/workbench-users.env`，每行一个：

```
root=密码:admin
bob=密码:user
```

`secrets/workbench.env` 里的 `LOGIN_USER` / `LOGIN_PASSWORD` 固定是管理员；两个文件都没有时用缺省 `admin` / `orbit`（管理员）。角色不写时按 `user`。

- 管理员：看得到测试和正式环境，用得了助手。
- 普通用户：只下发正式环境，服务端拒绝一切连测试库的请求；助手入口不显示，相关接口返回 403。

登录后页面左侧底部可以退出；除 `/api/login`、`/api/session`、`/api/logout`、`/api/health` 外，接口都要求会话。

## 浏览器里的 Agent

页面右下角的「OrBit 助手」是完整 Agent，不是普通聊天：每个回合由 `server/` 调起无头 `claude`，继承 `AGENT.md`、`.claude/skills/` 和 `.mcp.json` 里的八套库，能查库、读代码。

- **只有只读模式**：读仓库、查库、看存储过程；不改文件、不执行命令、不写库，`secrets/` 一律拒绝。这个限制在服务端，改请求参数也发不出去。
- 只接受本机访问；同一会话自动续聊，记录写在 `super-agent/conversations/`。

左侧导航第 3 项 `super-agent` 是完整页面版：左边是历史对话，能新建、切换、删除；每段对话把思考、工具调用和 diff 一并存下来，点开还能接着聊。页面右下角的「OrBit 助手」是同一个 Agent 的悬浮版，会自动带上你正在看的页面。

## SQL 语法检查

在功能详情的 SQL 阅读器中点击「语法检查」，或在右键菜单中选择同一项。工作台会在当前功能对应的数据源上使用 `SET PARSEONLY ON` 检查完整 SQL，然后关闭连接；只检查语法，不执行 SQL，也不校验表、字段等对象是否存在。

## 标准元对象关联图

从元数据库拉取 `Plugin Standard.dll` 标准元对象，用物理表字段生成对象间引用关系（例如 `Factory.EnterpriseId → Enterprise`）：

```powershell
.\.venv\Scripts\python.exe scripts\build_standard_metadata_graph.py --env jiban-mes-prod
```

产物：

- `library/{plant}/standard-metadata.json`：元对象、表字段、`references` / `referencedBy`
- `server/fixtures/standard-metadata-graph.json`：工作台「7 功能逻辑」只读展示的节点和关系

字段同名只代表 MES 的引用约定，不代表数据库存在外键约束。共用同一张表的多个元对象会各自带出相同字段关系。

## 给 Agent

会话入口是 [AGENT.md](AGENT.md)。查库时读 `.AGENTS/skills/mes-db/SKILL.md`。

## Claude Code 查库 MCP

项目根目录的 `.mcp.json` 固定注册八套单库 MCP，Claude Code 会从项目根目录启动 `.venv/Scripts/python.exe`。首次在新环境使用时先安装依赖：

```powershell
.\.venv\Scripts\python.exe -m pip install -r server\requirements.txt
```

然后重开 Claude Code 会话，或用 `/mcp` 检查连接。每个工具调用都会新建并关闭数据库连接；临时连接错误最多重试 3 次，存储过程执行不会自动重放。凭据只从 `secrets/{MCP名}.env` 读取，不写入 `.mcp.json`。
