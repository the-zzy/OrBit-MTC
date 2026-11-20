---
description: 交付物目录层级。放在仓库根 tasks/ 下，目录名用英文，第二段用 mes-db 的 MCP 名。
alwaysApply: false
---

# 交付物输出目录

路径：

```text
tasks/{MCP名}/{类别}/{功能英文名}/
```

`{MCP名}` 取当前 `.AGENTS/skills/mes-db/SKILL.md` 里这一套的英文名：`jiban-mes-test`、`jiban-mes-prod`、`zongzhuang-mes-test`、`zongzhuang-mes-prod`、`tongxin-mes-prod`、`guangyuan-mes-prod`、`guangyuan-wms-prod`、`shuma-mes-prod`。

`{类别}` 是 `dev`、`flow`、`plugin`、`ops` 之一。建表脚本用 `dev`。

`{功能英文名}` 用英文。建表时没有另给名字，就用表名。

`.sql` 使用 UTF-8。

任务交付物统一放仓库根的 `tasks/`。`library/{plant}/{command}/` 只放工作台拉取的功能元数据（`object.json` 及其引用的 SQL），不放任务交付脚本。
