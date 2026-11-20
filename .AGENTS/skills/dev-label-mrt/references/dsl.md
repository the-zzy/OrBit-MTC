# MRT DSL（JSON 模板）

由 `scripts/build_mrt_from_dsl.js` 生成 **JSON** `.mrt`（`ReportVersion: 2023.1.2`）。**不**用于现网 **2013 XML** 查询打印；那种走 [desktop-print.md](desktop-print.md)。

## 类型

| type | 用途 | 数据源 |
|------|------|--------|
| `document` | 单据（表头 + 明细表 + 可选签章） | `root` 扁平 |
| `report` | 汇总表 + 可选图表 + 明细 | `t1`, `t2`, … |

## document 骨架

```javascript
{
  type: "document",
  reportName: "FinishingEntry",
  reportAlias: "生产入库单",
  page: { width: 21, height: 14.8, orientation: "landscape" },
  header: {
    title: { text: "生产入库单", fontSize: 18, bold: true },
    barcode: { field: "finishingentry_name" },
    fields: [
      { name: "DocNo", label: "入库单号:", field: "finishingentry_name" },
    ],
  },
  table: {
    columns: [
      { field: "product_name", header: "产品名称", width: 3.0, align: "left" },
    ],
  },
  footer: { fields: [{ label: "仓管员:", width: 2.5 }] },
}
```

绑定语法：`{root.field_name}`。

## report 骨架

```javascript
{
  type: "report",
  reportName: "AndonSummary",
  reportAlias: "异常管理分析",
  page: { width: 21, height: 29.7, orientation: "portrait" },
  title: { text: "异常管理分析", fontSize: 16 },
  tables: [{
    dataSource: "t1",
    columns: [
      { field: "workcenter_name", header: "生产线", width: 6 },
    ],
  }],
  charts: [{
    title: "异常类型统计",
    dataSource: "t2",
    type: "StackedColumn",
    argumentField: "andon_type",
    series: [{ field: "qty_released", text: "已关闭", color: "#00B050" }],
    width: 19,
    height: 5.5,
  }],
}
```

图表 type：`StackedColumn` | `Column` | `Line` | `Pie` | `Area`。

## 执行

```bash
node .AGENTS/skills/dev-label-mrt/scripts/build_mrt_from_dsl.js path/to/spec.json path/to/out.mrt
node .AGENTS/skills/dev-label-mrt/scripts/validate_mrt.js path/to/out.mrt
```
