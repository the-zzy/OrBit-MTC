# PDOT 移动盘点 PDA 网关接口文档

| 项目 | 内容 |
|---|---|
| 功能名称 | 移动盘点（PDOT） |
| 适用环境 | 数码正式环境（shuma-mes-prod） |
| 文档版本 | V2.2 |
| 更新日期 | 2026-11-17 |
| 接口数量 | 2 个 |
| 数据格式 | JSON，UTF-8 |
| 网关交付 | 每个接口各一份 BP（ESB 编排）和 WG（Thirdparty API 列表）`.bson` |

## 一、调用约定

### 1.1 地址与调用链

```text
POST /thirdparty/mes/PDOTInitQuery  →  /system_mes/PDOTInitQuery  →  ESB SQL  →  dbo.APIBP_PDOTInitQuery
POST /thirdparty/mes/PDOTOperate    →  /system_mes/PDOTOperate    →  ESB SQL  →  dbo.APIBP_PDOTOperate
```

请求头：`Content-Type: application/json; charset=utf-8`

不再使用旧地址 `/pda/pdot/init-query`、`/pda/pdot/operate`。

### 1.2 网关返回包装

```json
{
  "state": true,
  "errcode": 200,
  "msg": "",
  "data": [
    {
      "returnMessage": "ServerMessage:操作成功",
      "returnValue": 0
    }
  ],
  "transactionId": "平台请求ID"
}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| state | boolean | 网关调用是否成功 |
| errcode | number | 网关状态码，成功为 200 |
| msg | string | 网关提示 |
| data | array | SQL 结果集；本接口固定返回一行，取 `data[0]` |
| transactionId | string | 平台请求 ID |

**业务成功与否必须看 `data[0].returnValue`**：`0` 成功，`-1` 失败；失败原因在 `data[0].returnMessage`。不要再读取旧字段 `success/code/message`。`state=true` 只代表网关调用成功，不等同于业务成功。

### 1.3 集合字段的读取方式

网关 SQL 出参是扁平列，不能直接返回多个结果集或嵌套数组。因此以下字段均为 **JSON 数组字符串**，PDA 必须再执行一次 JSON 解析：

- `plansJson`、`pdTypesJson`、`departmentsJson`、`listJson`
- `resultsJson`

例如 JavaScript：`const plans = JSON.parse(response.data[0].plansJson);`。空集合统一返回字符串 `"[]"`，不是 `null`。

---

## 二、初始化 / 查询：PDOTInitQuery

### 2.1 固定入参

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| action | string | 是 | `init` / `query` |
| pdOperator | string | 条件必填 | `init` 时必传，盘点工号 |
| queryType | string | 条件必填 | `query` 时必传：`checked` / `unchecked` / `location` / `assets` / `operators` |
| stocktakeId | string | 条件必填 | `checked` / `unchecked` / `assets` 时必传 |
| departName | string | 否 | 部门筛选；对应 `AssetDetail.IsSoftAsset`，空表示不过滤 |
| assets | array | 条件必填 | `queryType=assets` 时必传，1～100 条；单资产查询也传 1 条，不另设单资产动作 |

`assets` 的每项只传 `assetLotSN`。查询只带出资产信息，不执行盘点；每条独立返回匹配结果，单条未匹配不影响其他资产。

`queryType=checked` 支持按工号过滤：传入 `pdOperator` 时只返回该工号盘过的资产（`AssetDetail.Operator`），传空表示全部。盘点清单页使用该条件；盘点操作记录页仍按部门过滤。`pdOperator` **不做在职校验**，仅作为查询条件。

`queryType=operators` 用于工号下拉：把 `pdOperator` 当搜索词，按工号前缀或姓名模糊匹配在职人员，返回前 50 条到 `listJson`，每项为 `{ "personNumber": "1000001", "personName": "顾伟" }`。不要求 `stocktakeId`，复用现有出参，不改变网关契约。

`location` 只要求 `action=query`、`queryType=location`，不再要求 `stocktakeId`、`pdOperator` 或 `OrBitUserId`。

### 2.2 固定出参（data[0]）

| 字段 | 类型 | 说明 |
|---|---|---|
| operatorName | string | 人员姓名，仅 `init` 返回 |
| plansJson | string | 盘点计划 JSON 数组字符串，仅 `init` 返回 |
| pdTypesJson | string | 盘点类型 JSON 数组字符串，仅 `init` 返回 |
| departmentsJson | string | 部门 JSON 数组字符串，仅 `init` 返回 |
| listJson | string | 清单 JSON 数组字符串，仅 `query` 返回 |
| returnMessage | string | 业务消息 |
| returnValue | number | 0 成功，-1 失败 |

非当前动作使用的集合字段返回 `"[]"`，字段不会消失。

### 2.3 初始化

请求：

```json
{
  "action": "init",
  "pdOperator": "2061399",
  "queryType": "",
  "stocktakeId": "",
  "departName": "",
  "assets": []
}
```

成功响应：

```json
{
  "state": true,
  "errcode": 200,
  "msg": "",
  "data": [
    {
      "operatorName": "张三",
      "plansJson": "[{\"stocktakeId\":\"PD1500008\",\"stocktakeDescription\":\"生产部;冲压一车间\",\"stocktakeName\":\"2024年度固定资产盘点\"}]",
      "pdTypesJson": "[{\"pdType\":\"自盘\"},{\"pdType\":\"复盘\"}]",
      "departmentsJson": "[{\"departName\":\"生产部\"},{\"departName\":\"设备部\"}]",
      "listJson": "[]",
      "returnMessage": "ServerMessage:初始化成功",
      "returnValue": 0
    }
  ],
  "transactionId": "平台请求ID"
}
```

解析后结构：

```json
{
  "plans": [
    {
      "stocktakeId": "PD1500008",
      "stocktakeDescription": "生产部;冲压一车间",
      "stocktakeName": "2024年度固定资产盘点"
    }
  ],
  "pdTypes": [{ "pdType": "自盘" }, { "pdType": "复盘" }],
  "departments": [{ "departName": "生产部" }, { "departName": "设备部" }]
}
```

后台逻辑：校验在职人员；查询状态为 `10/20` 的 `Stocktake`；返回自盘/复盘；从有效 `AssetDetail.IsSoftAsset` 读取去重部门。

### 2.4 查询清单

请求示例（已盘）：

```json
{
  "action": "query",
  "pdOperator": "",
  "queryType": "checked",
  "stocktakeId": "PD1500008",
  "departName": "生产部",
  "assets": []
}
```

`listJson` 解析后的每项字段固定为：

| 字段 | 说明 |
|---|---|
| assetNum | 资产编号；地址清单为 null；assets 查询未匹配时回传原条码 |
| assetLotSN | 请求中的资产条码；仅 `assets` 查询返回，用于逐条对应 |
| description | 资产描述；地址清单为 null |
| status | 已盘点 / 未盘点 / 未匹配；地址清单为 null |
| roomer | 管理人；地址清单为 null |
| isSoftAsset | 部门/资产属性；地址清单为 null |
| runStatus | 运行状态；地址清单为 null |
| location | 当前存放位置描述；地址清单为 null |
| locationName | 地址编码；仅 `location` 返回 |
| locationDescription | 地址描述；仅 `location` 返回 |
| success | 本条是否匹配成功；仅 `assets` 查询返回 |
| message | 本条失败原因；仅 `assets` 查询返回 |

### 2.5 单条 / 批量资产信息查询

统一使用 `queryType=assets`，不区分单资产和多资产动作。单条查询时 `assets` 仅放 1 项：

```json
{
  "action": "query",
  "pdOperator": "",
  "queryType": "assets",
  "stocktakeId": "PD1500008",
  "departName": "",
  "assets": [
    { "assetLotSN": "ZC20240001" },
    { "assetLotSN": "ZC20240002" }
  ]
}
```

后台按当前计划所属公司匹配 `AssetNum` 或 `EquipmentNumber`，归一返回 `assetNum`，并根据当前计划返回“已盘点/未盘点”。未匹配项返回 `success=false`、`status=未匹配` 和 `message`，其他条目仍正常返回。PDA 扫码后先调用本查询填充网格，点击“盘点”时再统一调用 `batchCheck`。

---

## 三、盘点操作：PDOTOperate

### 3.1 固定入参

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| action | string | 是 | `batchCheck` / `unused` / `cancel` |
| stocktakeId | string | 是 | 盘点计划单号 |
| pdOperator | string | 条件必填 | `batchCheck` 时必传 |
| pdType | string | 条件必填 | `batchCheck` 时必传：`自盘` / `复盘` |
| zoneCode | string | 条件必填 | `batchCheck` 时必传 |
| assets | array | 条件必填 | `batchCheck` 时必传，1～100 条；单条盘点也传 1 条 |
| assetNum | string | 条件必填 | `unused` / `cancel` 时必传 |

`assets` 是请求 JSON 中的真实数组。BP 的 `paramsDocs` 使用 `Array + children`，SQL 节点将 `${$.http.assets}` 传给 `@AssetsJson`，过程内使用 `OPENJSON` 解析。**单条盘点与批量盘点统一使用 `batchCheck`，区别仅在于 `assets` 数组长度。**

### 3.2 固定出参（data[0]）

| 字段 | 类型 | 说明 |
|---|---|---|
| description | string | 单条盘点成功时的资产描述，其他情况为空串 |
| roomer | string | 单条盘点成功时的管理人，其他情况为空串 |
| unUsedNum | string | 单条盘点/置闲置成功时的资产编号 |
| resultsJson | string | 单条或批量盘点明细 JSON 数组字符串；置闲置/取消为 `"[]"` |
| total | number | 处理条数；置闲置/取消成功为 1 |
| successCount | number | 成功条数 |
| failCount | number | 失败条数 |
| returnMessage | string | 业务消息 |
| returnValue | number | 0 成功，-1 失败；批量允许部分明细失败 |

`resultsJson` 解析后的每项：

| 字段 | 类型 | 说明 |
|---|---|---|
| assetLotSN | string | 请求中的资产条码 |
| success | boolean | 本条是否成功 |
| message | string | 本条处理结果或失败原因 |
| description | string | 资产描述，失败时为空串 |
| roomer | string | 管理人，失败时为空串 |
| assetNum | string | 归一后的资产编号 |

### 3.3 盘点（batchCheck，支持单条和批量）

单条盘点请求（`assets` 仅 1 条）：

```json
{
  "action": "batchCheck",
  "stocktakeId": "PD1500008",
  "pdOperator": "2061399",
  "pdType": "自盘",
  "zoneCode": "A-01-01",
  "assets": [
    { "assetLotSN": "ZC20240001" }
  ],
  "assetNum": ""
}
```

批量盘点请求：

```json
{
  "action": "batchCheck",
  "stocktakeId": "PD1500008",
  "pdOperator": "2061399",
  "pdType": "自盘",
  "zoneCode": "A-01-01",
  "assets": [
    { "assetLotSN": "ZC20240001" },
    { "assetLotSN": "ZC20240002" },
    { "assetLotSN": "ZC20240003" }
  ],
  "assetNum": ""
}
```

成功响应示例：

```json
{
  "state": true,
  "errcode": 200,
  "msg": "",
  "data": [
    {
      "description": "",
      "roomer": "",
      "unUsedNum": "",
      "resultsJson": "[{\"assetLotSN\":\"ZC20240001\",\"success\":true,\"message\":\"盘点完成\",\"description\":\"数控冲床\",\"roomer\":\"李四\",\"assetNum\":\"ZC20240001\"},{\"assetLotSN\":\"ZC20240003\",\"success\":false,\"message\":\"设备编号[ZC20240003]已自盘过，请勿重复盘点\",\"description\":\"\",\"roomer\":\"\",\"assetNum\":\"ZC20240003\"}]",
      "total": 2,
      "successCount": 1,
      "failCount": 1,
      "returnMessage": "ServerMessage:批量盘点完成：成功 1 条，失败 1 条",
      "returnValue": 0
    }
  ],
  "transactionId": "平台请求ID"
}
```

单条盘点（`assets` 仅 1 条）成功时，`returnValue=0`，`description/roomer/unUsedNum` 返回该资产信息，`resultsJson` 同时保留一条完整明细；单条业务失败时 `returnValue=-1`，失败原因在 `returnMessage` 和 `resultsJson` 中。

批量请求本身校验通过并正常处理完毕时，顶层 `returnValue=0`；每条是否成功以 `resultsJson` 中的 `success` 为准。每条独立处理，单条失败不阻断后续条目。单次最多 100 条。

### 3.4 置闲置（unused）

```json
{
  "action": "unused",
  "stocktakeId": "PD1500008",
  "pdOperator": "",
  "pdType": "",
  "zoneCode": "",
  "assets": [],
  "assetNum": "ZC20240001"
}
```

成功后更新 `AssetDetail.NotActiver=1` 和对应 `StocktakeCheckList.NotActiver=1`，`unUsedNum` 返回本次资产编号。

### 3.5 取消盘点（cancel）

```json
{
  "action": "cancel",
  "stocktakeId": "PD1500008",
  "pdOperator": "",
  "pdType": "",
  "zoneCode": "",
  "assets": [],
  "assetNum": "ZC20240001"
}
```

取消仅清空匹配资产的 `AssetDetail.StockTakeId`，不删除 `StocktakeCheckList` 明细。

---

## 四、后台规则与交付文件

1. 条码先转大写，再按顺序归一为 `AssetNum`：① 直接匹配资产编号；② 匹配 `EquipmentNumber`；③ 去掉左侧前导 0 后匹配；④ 去掉前导 0 后按「公司码 + 资产编号」匹配（如数码设备码 `10103001185` → 公司 `1010` + 资产编号 `3001185`）。查询与盘点使用同一套规则。
2. 校验在职人员、开放中的盘点计划、盘点类型、区域码和有效资产。**联调临时开关**：两个过程的 `@SkipOperatorCheck = 1` 时跳过“工号是否在职”校验，其余校验不变；恢复校验时改为 `0` 并重新部署。
3. 计划外资产自动新增 `StocktakeCheckList`，备注“新增配置项”；OA 通知调用已按需求注释，不会发送消息。
4. 自盘检查 `FirstCheckQTY`，复盘检查 `ReCheckQTY`，阻止重复盘点。
5. 过程遵循 SQL Server 2016、TRY/CATCH、无显式事务、无 Orbit 14 参；成功 `RETURN 0`，失败 `RETURN -1`。为兼容 SQL Server 2016 RTM，首次部署使用 `CREATE PROCEDURE`，已有对象更新时改为 `ALTER PROCEDURE`。

| 文件 | 用途 |
|---|---|
| `APIBP_PDOT_Gateway.sql` | 两个网关入口过程；PDA/网关只调用这两个过程 |
| `APIBP_PDOT_Gateway_TestCase.sql` | 人工测试用例，未在数据库执行 |
| `PDA_PDOT_Procedures.sql` | 原业务过程草稿，保留参考，不是本次网关入口 |
| `gateway-apis.json` | 入参、出参、成功响应及过程映射的唯一元数据 |
| `New-PDOT网关Bson.ps1` | 向平台取流水号并生成 BP/WG；同时执行结构断言 |
| `00_交付清单.md` | 本需求的导入顺序、部署状态、测试数据与待办 |
| `PDOT_TestData_总装资产.sql` | 总装测试库三条联调资产，可重复执行 |
| `BP_PDOTInitQuery_2611171150.bson`、`WG_PDOTInitQuery_2611171150.bson` | 初始化/查询的编排与网关导入件 |
| `BP_PDOTOperate_2611171150.bson`、`WG_PDOTOperate_2611171150.bson` | 盘点操作的编排与网关导入件 |
| `变更说明.md` | 实际流水号、导入顺序和人工注意事项 |

## 五、变更记录

| 版本 | 日期 | 变更内容 |
|---|---|---|
| V1.0 | 2026-11-17 | 初始业务草稿 |
| V2.0 | 2026-11-17 | 按 dev-api-interface v2.1.0 改为 BP+WG；修正网关 URL、返回包装、固定出参及数组/JSON 调用方式 |
| V2.1 | 2026-11-17 | 移除 check 单条盘点；batchCheck 统一支持单条和批量，单条时 assets 传 1 条 |
| V2.2 | 2026-11-17 | 新增 queryType=assets；同一 assets 数组支持 1～100 条资产信息查询，扫码只带数据，点击盘点再批量提交网格 |
