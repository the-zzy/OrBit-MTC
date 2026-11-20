# 电脑打印文件

查询插件 **数据模板 / 数据界面 / 查询打印**：整表预览或打印，**不是** PDA 小签。

## 识别

- 标题 + 列标题 + **多行** DataBand（或 StiTable）
- 按钮常见：`IsPrintMethod = 1`，`IsPreview = 1`，`LabelFileName = N'*.mrt'`
- 数据来自查询方法结果集，与网格列一致

## 数据绑定

| 项 | 规范 |
|----|------|
| 数据源名 | 常见 `t1` |
| NameInSource | 常见 `SQLDateSet` |
| 单元格 | `{t1.列名}`，列名 = 过程/查询 **SELECT 列名**（含中文列名） |
| 禁止 | `{root.xxx}`、`LabelData`（除非现场确认 MES 例外） |

## 版式（深圳总装 Orbit 现网）

| 项 | 建议 |
|----|------|
| 形态 | **Stimulsoft 设计器 XML**，`ReportVersion` **2013.3.1800** |
| 参照 | 2013.3.1800 的 XML。本仓库没有 CHEQ 样例文件，按下面的段数写 |
| 纸张 | A4 **横向** 29.7×21 cm，`PaperSize` A4 |
| 边距 | 尽量小（如 0.15 cm），表格宽 = 页宽 − 2×边距 |
| 标题 | **ReportTitleBand**（只首页一次） |
| 表头 | **GroupHeaderBand**（换页可重复列标题） |
| 字体 | 与现网一致（如宋体 10/24）；用户要求不改字号时只调 band 宽度 |

## 2013 设计器打不开

设计器弹「索引超出了数组界限」时，先对字符串段数，不要先改版式。2013.3.1800 按固定下标读取，少一段就越界。对照下表：

| 属性 | 能打开的写法 | 会打不开 |
|------|----------------|----------|
| `Font` | `宋体,8,Regular` 或 `宋体,10,Bold`（名称、字号、样式三段） | `宋体,8` |
| `Border` | `All;Black;1;Solid;False;4;Black` 或 `None;Black;1;Solid;False;4;Black`（七段） | 单独的 `None` |
| `TextBrush` | 颜色名 `Black`，或四段 `[255:200:80:0]`（透明度、红、绿、蓝） | `[200:80:0]` |
| `Brush` | `Transparent`，或三段 `[230:230:230]` | 不要套用 JSON 的 `solid:91,155,213` |

JSON 贴标的字体、边框、颜色写法不能抄进这份 XML。生成后检查：每个 `<Font>` 都是三段，每个 `<Border>` 都是七段，自定义 `<TextBrush>` 都是四段。

## 生成方式（按优先级）

1. **按本节写 XML**：Dictionary 列、GroupHeader/DataBand 绑定和 `ReportName` 跟结果集列名对齐。字体、边框、颜色用上面的段数。
2. **功能目录生成脚本**（列多时）：`tasks/{MCP名}/dev/{功能英文名}/generate_*_print.js`。输出 XML 使用数字 `Ref`，不要写易歧义的日期 Sort。
3. **DSL → JSON**（`build_mrt_from_dsl.js`）：适用于不要求 2013 XML 的环境。现网查询打印优先 XML。

## 设计器 / SSMS 预览数据

- 过程在**非报表服务器**可能 `RETURN -1` 无结果集 → 设计器 EXEC 报「无法找到表 0」。
- 做法：功能目录提供 **UNION 模拟 SELECT** 或 `DECLARE` + 条件 EXEC（仅报表库）。

## MES 预览缩放

- 查询打印窗 **默认 100%**，宽屏时页面两侧有灰边；拖大预览区 ≈ **页宽**缩放。
- **`.mrt` 无法保存「打开即页宽」**；模板侧应把表格铺满纸面减少白纸内空边。
- 若必须一打开满宽：需 MES 客户端预览 Load 时设 Stimulsoft 页宽缩放（程序改动）。

## 按钮挂接（不写库时只写变更说明）

| 配置 | 典型值 |
|------|--------|
| MethodName | 业务语义英文名 |
| SQLDoMethod | 与 ClickOnQuery 相同查询过程 |
| MainViewParameter | 与 ClickOnQuery 一致 |
| IsPrintMethod / IsPreview | 1 / 1 |
| LabelFileName | `N'{模板文件名}.mrt'` |

这些值写进同目录的 `变更说明.md`。本技能不生成、不执行按钮 SQL。

文件名建议：`{业务}QueryPrint.mrt`、`*SummaryReport.mrt`。放在 `tasks/{MCP名}/dev/{功能英文名}/`。
