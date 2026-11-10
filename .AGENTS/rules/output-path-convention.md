---
description: 交付物目录层级。目录名用英文，第一段用 mes-db 的 MCP 名。
alwaysApply: false
---

# 交付物输出目录

路径：

```text
{MCP名}/{类别}/{功能英文名}/
```

`{MCP名}` 取当前 `.AGENTS/skills/mes-db/SKILL.md` 里这一套的英文名：`jiban-mes-test`、`jiban-mes-prod`、`zongzhuang-mes-test`、`zongzhuang-mes-prod`、`tongxin-mes-prod`、`guangyuan-mes-prod`、`guangyuan-wms-prod`。

`{类别}` 是 `dev`、`flow`、`plugin`、`ops` 之一。建表脚本用 `dev`。

`{功能英文名}` 用英文。建表时没有另给名字，就用表名。

`.sql` 使用 UTF-8。
