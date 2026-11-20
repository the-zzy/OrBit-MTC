---
name: dev-label-mrt
description: >-
  标签生成：产出或修改 Stimulsoft .mrt。贴标小签和电脑打印模板都走这里。
  用户要 MRT、Stimulsoft、LabelFileName、箱贴、PDA 贴标、查询打印、数据模板时先读。
  未确认是贴标还是电脑打印之前不要生成文件。不写库，不改按钮配置。
version: "3.1.0"
framework: OrbitMES
alwaysApply: false
agent_created: true
---

# 标签生成（Stimulsoft .mrt）

**职责**：生成或修改 `.mrt`，校验，本地预览，写 `变更说明.md`（含 `LabelFileName`）。**不写库**。按钮配置不在本技能里生成。

---

## 0. 硬规则

1. 用户**明确选定类型前**：禁止生成或覆盖 `.mrt`，禁止跑生成脚本，禁止写交付用的 `变更说明.md`。
2. 类型仅二选一：**电脑打印文件** | **贴标标签**。
3. 需求含糊时先问：

   > 要做 **电脑打印文件**（查询整表预览/打印，如货柜汇总表），还是 **贴标标签**（PDA/外箱小签，厘米尺寸）？

4. 用户说「查询数据模板 / 数据界面 / 查询打印」→ **默认倾向电脑打印**，仍须用户确认后再生成。
5. 确认后在 `变更说明.md` 首表写死 **MRT 类型**，再进入生成。

---

## 1. 类型对照

| 维度 | 电脑打印文件 | 贴标标签 |
|------|--------------|----------|
| 用途 | 电脑预览/打印 **整张结果表** | 贴箱/贴物料/PDA **一行一签** |
| 页面 | A4 或宽纸（如 29.7×21 横向） | 厘米小页（如 10.5×7.5） |
| 数据源 | `t1`，`NameInSource` 常 `SQLDateSet` | `LabelData` / `root` |
| 绑定 | `{t1.列名}` = 查询/过程 **结果集列名** | `{root.字段名}` |
| 文件形态 | 现网多 **XML**（2013 设计器） | 新建多 **JSON**（2023.1.2） |
| 分支文档 | [desktop-print.md](references/desktop-print.md) | [sticker-label.md](references/sticker-label.md) |

**禁止混用**：电脑打印勿用 `{root.x}` / `LabelData`；贴标勿用 `{t1.x}`（无现场确认）。

旧工作台里的 `TVShipContainerSummaryReport.mrt`、`CartonLabel.mrt` 不在本仓库。版式以分支文档里的字段规则为准，不要按旧路径去读文件。

---

## 2. 执行流程（类型确认后）

**输出目录**：

```text
tasks/{MCP名}/dev/{功能英文名}/
```

`{MCP名}` 用 `.AGENTS/skills/mes-db/SKILL.md` 里这一套的英文名。`{功能英文名}` 用英文。目录约定见 `.AGENTS/rules/output-path-convention.md`。`.mrt` 和 `变更说明.md` 都放在这个目录，不放仓库根。

### Step 0 — 确认类型

二选一：`1 电脑打印` / `2 贴标`。未答则停止。

### Step 1 — 收集

| 项 | 电脑打印 | 贴标 |
|----|----------|------|
| 模板英文名 | PascalCase，如 `*QueryPrint`、`*SummaryReport` | 如 `CartonLabel` |
| 字段 | 与 **SQL 结果集列名** 一致 | root 字段 + 条码字段 |
| 尺寸 | A4 横/宽表 | 实物厘米 |
| 按钮 | 是否仅 `.mrt`，或还要在变更说明里写 `LabelFileName` | 同左 |

### Step 2 — 生成

- **电脑打印**：优先按 [desktop-print.md](references/desktop-print.md) 写 XML。复杂列多时可在功能目录写 `generate_*_print.js`。
- **贴标**：`node .AGENTS/skills/dev-label-mrt/scripts/generate_mrt.js {输出}.mrt`，或功能目录 `generate_*_label.js`。
- **DSL 新建 JSON**：见 [dsl.md](references/dsl.md)，再跑 `scripts/build_mrt_from_dsl.js`。

预览依赖 `stimulsoft-reports-js`。未安装时在 `.AGENTS/skills/dev-label-mrt/` 执行 `npm install`。校验脚本不依赖这个包。

### Step 3 — 校验

```bash
node .AGENTS/skills/dev-label-mrt/scripts/validate_mrt.js {路径}/{名}.mrt
```

上面这条只适用于 JSON 模板（`ReportVersion` 2023.1.2）。

**XML 电脑打印模板**（2013.3.1800）不用这条 JSON 校验。自检 `Ref` 为数字，并按 [desktop-print.md](references/desktop-print.md) 核对字体三段、边框七段、文字色格式。缺段时设计器打开即报「索引超出了数组界限」。

### Step 4 — 预览（依赖已安装时）

```bash
node .AGENTS/skills/dev-label-mrt/scripts/preview_mrt.js {mrt路径}
node .AGENTS/skills/dev-label-mrt/scripts/preview_mrt_embedded.js {mrt路径}
```

第二条用贴标的 `root` 样例数据。电脑打印另在功能目录提供 SSMS 或设计器用的 **SELECT 样例 SQL**。过程在客户端没有结果集时，用 `UNION` 模拟。

### Step 5 — 变更说明.md

必含：**MRT 类型**、数据源与列、页面尺寸、`LabelFileName`、上传路径、挂接步骤。打印按钮要写 `IsPrintMethod=1`。需要预览时写 `IsPreview=1`。本技能只把这些写进说明，不执行入库。

---

## 3. 双轨技术要点

| 项 | JSON 贴标 / DSL | XML 电脑打印 |
|----|-----------------|--------------|
| ReportVersion | `2023.1.2` | `2013.3.1800` |
| 勿加 | — | 非数字 `Ref`、易歧义日期 Sort |
| 标题 band | 按 DSL/组件 | **ReportTitleBand**（仅首页）；表头用 GroupHeader |
| 预览满宽 | — | MES 默认 100% 缩放；页宽缩放需客户端，见 desktop-print |

组件字段说明：[stimulsoft-components.md](references/stimulsoft-components.md)  
默认字段占位（无清单时）：[field-patterns.md](references/field-patterns.md)

---

## 4. 不在本技能里做的

| 任务 | 怎么处理 |
|------|----------|
| 已有查询元怎么用、打印按钮现在怎么挂 | 读 `.AGENTS/skills/ops-query-metadata-survey/SKILL.md`。那份只读，不生成 `.mrt` |
| 按钮 SQL、`SysMetadataMethod`、写库 | 不写。挂接信息只留在 `变更说明.md` |
| 建表 | `.AGENTS/skills/dev-create-table/SKILL.md` |

---

## 5. 禁止

- 未确认类型就生成
- 查询「数据模板」默认做成贴标 `root`
- `.mrt` 放仓库根目录
- 未经要求写 `label` 表或上传 MOMpro

---

## 6. 目录

```
dev-label-mrt/
├── SKILL.md
├── references/
│   ├── desktop-print.md
│   ├── sticker-label.md
│   ├── dsl.md
│   ├── stimulsoft-components.md
│   └── field-patterns.md
└── scripts/
    ├── validate_mrt.js
    ├── build_mrt_from_dsl.js
    ├── generate_mrt.js
    ├── preview_mrt.js
    └── preview_mrt_embedded.js
```
