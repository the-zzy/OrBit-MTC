# 贴标标签

PDA 或桌面打印机 **外箱 / 物料 / 内盒**。**一行业务数据 ≈ 一张物理标签**。

## 何时用

用户 **明确** 下列之一：

- PDA、贴外箱/物料、内盒贴、条码小签
- 给出 **厘米** 尺寸（如 10.5×7.5）
- **不要** 整表 Excel 式预览

## 何时不用

| 用户说法 | 走 |
|----------|-----|
| 查询数据模板、数据界面、查询打印、多列网格 | [desktop-print.md](desktop-print.md) |
| 仅说「标签」但上下文是 VDRPQ/CHEQ **查询网格** | 先 SKILL §0 二选一 |

## 数据绑定

| 项 | 规范 |
|----|------|
| 数据库名 | `LabelData` |
| 表名 | `root` |
| 绑定 | `{root.字段名}` |

## 生成

| 方式 | 命令/位置 |
|------|-----------|
| 通用箱贴 | `node .AGENTS/skills/dev-label-mrt/scripts/generate_mrt.js {输出}.mrt` |
| 业务定制 | 功能目录 `generate_*_label.js` |
| DSL 单据/复杂版 | [dsl.md](dsl.md) + `build_mrt_from_dsl.js` |

输出 **JSON**，`ReportVersion` **2023.1.2** → 必须跑 `validate_mrt.js`。

## 样例

交付文件写到 `tasks/{MCP名}/dev/{功能英文名}/`。箱贴默认字段见 [field-patterns.md](field-patterns.md)（英文驼峰）。**查询行中文列名**贴标按 MES 传入字段单独定义，勿套用箱贴默认名。
