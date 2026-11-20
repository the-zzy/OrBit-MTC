# Stimulsoft 组件参考

本仓库 **两种 .mrt 形态**：

| 形态 | 用于 | 组件表示 |
|------|------|----------|
| **JSON** | 贴标、DSL 新建 | `Ident: "StiText"` 等 |
| **XML** | 深圳总装电脑打印 | `type="Text"`, `Ref="数字"` |

以下字段说明以 **JSON** 为主。电脑打印 XML（2013.3.1800）不要抄下面的分号字体和 `solid:` 颜色，格式以 [desktop-print.md](desktop-print.md) 的「2013 设计器打不开」为准。

---

## StiTable（表格）

用于单据明细行展示。

**JSON 结构关键字段：**
- `Ident: "StiTable"` — 组件类型
- `DataSourceName` — 绑定的数据源名称（如 `t1`）
- `RowCount` — 数据行数（自动扩展）
- `HeaderRowsCount` — 表头行数
- `Columns` — 列数
- `Components` — 子组件列表（StiTableCell）

**StiTableCell 关键字段：**
- `Text.Value` — 显示文本或绑定表达式（如 `{t1.product_name}`）
- `Type` — 类型：`DataColumn`(数据绑定), `Expression`(表达式), `SystemVariables`(系统变量如Line)
- `DataSourceName` — 数据源（继承）
- 单元格按顺序排列，第一个为表头行

## StiChart（图表）

用于报表统计图。

**JSON 结构关键字段：**
- `Ident: "StiChart"` — 组件类型
- `Series[]` — 数据系列
  - `Ident`: 图表类型（`StiStackedColumnSeries` 等）
  - `ValueDataColumn`: 数值字段（如 `t2.qty_released`）
  - `ArgumentDataColumn`: 分类字段（如 `t2.andon_type`）
  - `Title.Value`: 系列名称
  - `Brush`: 颜色填充
- `Area` — 绘图区配置
  - `YAxis`, `XAxis` — 坐标轴
  - `GridLinesHor`, `GridLinesVert` — 网格线
- `Legend` — 图例配置
- `Title.Text` — 图表标题

### 图表类型 Ident

| Ident | 说明 |
|-------|------|
| `StiColumnSeries` | 柱状图 |
| `StiStackedColumnSeries` | 堆叠柱状图 |
| `StiLineSeries` | 折线图 |
| `StiPieSeries` | 饼图 |
| `StiAreaSeries` | 面积图 |

## StiText（文本）

- `Text.Value` — 显示文本
- `Font` — 字体格式：`字体名称;字号;样式;`（如 `微软雅黑;12;Bold;`）。字号不能空，`Microsoft YaHei;;Bold;` 设计器打不开
- `HorAlignment`, `VertAlignment` — 对齐方式
- `Type` — 类型：`Expression`(表达式), `DataColumn`(数据列)
- `Border` — 边框：`All;;;;;;;solid:0,0,0`
- `Brush` — 背景色：`solid:91,155,213`
- `TextBrush` — 文字色：`solid:255,255,255`

## StiBarCode（条码）

- `BarCodeType.Ident` — 条码类型
  - `StiCode128AutoBarCodeType` — Code128 自动
  - `StiEAN128aBarCodeType` — EAN128
- `Code.Value` — 条码值（可绑定数据）
- `ShowLabelText` — 是否显示标签文字
- `AutoScale` — 自动缩放

## StiImage（图片）

- `ImageURL.Value` — 图片路径/URL
- `Image` — 内嵌 base64 图片数据

## 通用属性

- `ClientRectangle` — 位置和尺寸：`left,top,width,height`
- `Border` — 边框样式
- `Brush` — 背景填充
- `CanGrow`, `GrowToHeight` — 自动扩展高度
