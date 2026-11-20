---
name: dev
description: >-
  开发调度。用户输入 /dev 时使用。只调度开发相关技能：建表、梳理已有功能、看板、API、标签、工具函数。
  不做运维排错，不修生产事故。
---

# 开发调度

用户说了 `/dev`，这一轮只做开发。不排错，不修生产数据，不转去运维技能。

本技能只点名下一份要读的技能。规范、步骤、交付格式以那份技能为准，不要在这里自己编。

## 先定库

要查库、看过程、写交付到 `tasks/` 时，先读 `.AGENTS/skills/mes-db/SKILL.md`，选定唯一一套库。查 `SELECT` 前再读 `.AGENTS/skills/sql-query-safety/SKILL.md`。

## 按意图点名

| 用户要做什么 | 读这份 |
|---|---|
| 新建或改 `{表名}_MTable.sql` | `.AGENTS/skills/dev-create-table/SKILL.md` |
| 已有标准元怎么用（先复用 survey，没有才梳，须带流程图） | `.AGENTS/skills/ops-metadata-survey/SKILL.md` |
| 已有查询元怎么用（同上） | `.AGENTS/skills/ops-query-metadata-survey/SKILL.md` |
| 已有工位端事务怎么用（同上） | `.AGENTS/skills/ops-static-txn-survey/SKILL.md` |
| 已有 PDA 事务怎么用（同上） | `.AGENTS/skills/ops-mobile-txn-survey/SKILL.md` |
| 查插件、元对象、查询元字段和按钮 | `.AGENTS/skills/mes-meta-query/SKILL.md` |
| 看板、ECharts、`WebAPI_` | `.AGENTS/skills/dev-kanban-echart/SKILL.md` |
| 对外 API、网关 bson、ESB | `.AGENTS/skills/dev-api-interface/SKILL.md` |
| 标签 / `.mrt` / 电脑打印模板 | `.AGENTS/skills/dev-label-mrt/SKILL.md` |
| 主键、消息、邮件等通用函数 | `.AGENTS/skills/dev-utils-toolkit/SKILL.md` |
| 新建或改页面版式 | `.AGENTS/skills/dev-frontend-design/SKILL.md` |

一次需求要几份技能时，按上表列出顺序，先告诉用户再逐个 Read。未确认方案前不要开写交付。

## 还没有的开发技能

下面这些旧工作台有，这边还没迁。用户要做时直接说还没迁，不要用梳理技能顶替新建，也不要自己编一整套流程：

- 新建标准元、更新标准元
- 新建查询元、按钮、弹窗
- 新建 MES 事务、PDA 事务
- 注册插件

## 禁止

- 去做 `/ops` 那一支的事（报错排查、修数据、联系运维执行）
- 跳过点名的技能，直接手写交付
- 一次需求里混进无关的看板、API、标签，除非用户点名要
