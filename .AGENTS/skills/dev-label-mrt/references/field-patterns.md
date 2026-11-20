# MRT 字段模式参考

用户**未提供**字段清单时的占位。**查询电脑打印**必须用过程 **结果集列名**（常为中文），勿套用下列英文默认名。

## 标签模板（纸箱/条码）

- `CompanyName` — 公司名称
- `LogoUrl` — 公司 Logo URL
- `BoxNo` — 箱号
- `Model` — 型号
- `Quantity` — 数量
- `WorkOrderNo` — 工单号
- `CustomerPoNo` — 客户 PO 号
- 条码字段：`ItemCode1` ~ `ItemCodeN`

## 文档模板字段（单据打印）

通用表头字段：
- `DocNo` — 单据编号
- `Date` — 日期
- `FactoryName` — 工厂名称
- `DivisionName` — 部门名称
- `WarehouseName` — 仓库名称
- `CreateUserName` — 制单人
- `ApproveUserName` — 审核人

明细表格字段：
- `ItemSequence` — 行号
- `MoNo` — 工单号
- `ProductName` — 产品名称
- `ProductDesc` — 产品描述
- `ItemQtyEntry` — 数量
- `UomName` — 单位

## 报表模板字段

取决于业务数据，通常包含：
- 维度字段：日期、产品、产线、类型等
- 数值字段：数量、金额、工时等
- 统计字段：合计、平均值等

## 命名规范

- 字段名使用驼峰命名（如 `workcenterName`）
- 数据源名使用 `t1`, `t2`, `t3`（多个数据源时）
- 单位统一使用厘米（centimeters）
