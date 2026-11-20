---
name: ops
description: >-
  运维调度。用户输入 /ops 时使用。流程：定库 → 判类型 → 有 survey 就复用，没有才解析（含流程图）。
  不做功能开发，不新建表、元对象、看板、API、标签。
---

# 运维调度

用户说了 `/ops`，这一轮只做运维。不建功能，不转去开发技能。

本技能只定流程和点名下一份技能。解析细节以对应梳理技能为准。

## 流程

```text
定库 → 判类型 → 已有 survey.md？
              ├─ 有 → 直接读，不重解析
              └─ 没有 → 读对应梳理技能，第一次写出流程图 + 要点
```

### 1. 定库

先读 `.AGENTS/skills/mes-db/SKILL.md`，选定唯一一套库。任何 `SELECT` 前再读 `.AGENTS/skills/sql-query-safety/SKILL.md`。

### 2. 判断功能类型

手上要有插件命令、功能名或界面名。都没有就问。

读 `.AGENTS/skills/mes-meta-query/SKILL.md`，查 `PluginFileName`，不要按命令名猜：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 `
  -Env {MCP名} -Action plugin -Key {插件命令}
```

只记得中文名时用 `-Action search`。

| PluginFileName | 类型 | survey 路径 | 没有旧稿时读 |
|---|---|---|---|
| `Plugin Standard.dll` | 标准元对象 | `tasks/{MCP名}/flow/{MetadataName}/survey.md` | `.AGENTS/skills/ops-metadata-survey/SKILL.md` |
| `Plugin Query.dll` | 查询元对象 | `tasks/{MCP名}/flow/{PluginCommand}/survey.md` | `.AGENTS/skills/ops-query-metadata-survey/SKILL.md` |
| `PluginMESStaticTxn.dll` | 静态事务 | `tasks/{MCP名}/flow/{PluginCommand}/survey.md` | `.AGENTS/skills/ops-static-txn-survey/SKILL.md` |
| `PluginMESMobile.dll` | 移动事务 | `tasks/{MCP名}/flow/{PluginCommand}/survey.md` | `.AGENTS/skills/ops-mobile-txn-survey/SKILL.md` |

对不上这四类就停，不要硬套。

### 3. 先复用，没有才解析

先看上表对应路径有没有 `survey.md`：

- **有**：直接读。用里面的流程图和要点回答本次问题。不要重新查库扒过程，除非用户明确说配置变了、要重梳，或旧稿写明说不清且这次能补上。
- **没有**：Read 对应梳理技能，按它的规范**第一次**写出 `survey.md`。必须有一张页面流程图，以及关键操作要点。写完再拿这份回答问题。

`survey.md` 就在这个功能目录下。下次同一功能直接读它，不要再查库重梳。

### 4. 页面和取数都是标准的

每个功能同一套页面、同一套拉取。不要按功能另写查询、另画字段表。梳理要做的是分析。

工作台没起来先跑 `scripts/start-workbench.ps1`。正式库工厂：基板 `jiban`、总装 `zongzhuang`、通信 `tongxin`、光元 MES `guangyuan-mes`、光元 WMS `guangyuan-wms`、数码 `shuma`。打开 `http://127.0.0.1:3000/functions/{plant}/{命令}`。

| 类型 | 固定页签 |
|---|---|
| 标准元对象、查询元对象 | Table 表结构、DataObject 数据对象、PageStyle 页面样式、ValueList 值列表、MetaMethod 元对象方法 |
| 静态事务、移动事务 | PageStyle、ValueList、MetaMethod |

点当前页的「拉取当前页」。结果在 `library/{plant}/{命令}/object.json` 和它引用的 SQL。分析读这份：看见什么、要满足什么、点下去写成什么、失败怎样。

| 页 | 拉取 |
|---|---|
| 表结构 | `POST /api/functions/{plant}/{命令}/pull/table` |
| 数据对象 | `POST /api/functions/{plant}/{命令}/pull/procedure/{MainView\|TreeView\|SaveData\|DeleteView}` |
| 页面样式、方法 | `POST /api/functions/{plant}/{命令}/pull/style` |
| 值列表 | `POST /api/functions/{plant}/{命令}/pull/valuelists` |

`survey.md` 只写分析：干什么、怎么用、一张流程图、说不清的。字段、按钮、表结构以工作台和 `object.json` 为准，不另抄一份。

测试库没有这一页。这时才退回对应梳理技能里的查询，并在 survey 里注明没走标准拉取。不要把正式页当成测试库的界面。

### 5. 排查说明（需要时）

现场结论、和 survey 无关的临时证据，放到：

```text
tasks/{MCP名}/ops/{简短英文主题}/
```

功能怎么用仍以 `flow/.../survey.md` 为准，不要把整份逻辑再抄一份到 `ops/`。

## 还没有、以后再补

- 固定异常目录 / 对话排错
- 结构化诊断报告模板
- 受控写库、清数维护

## 禁止

- 去做 `/dev` 那一支的事
- 已有 `survey.md` 还整份重解析（除非用户要求重梳）
- 第一次梳理不画流程图
- 未授权写库或改对象
