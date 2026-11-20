# API 网关（两步 bson）

> **Agent 入口**：[`../SKILL.md`](../SKILL.md)  
> **适用范围**：所有经 HTTP 进 MES 的接口（**含设备 GET/SUBMIT** 与报表查询），交付均为 **BP + WG** 两个 bson；过程写法见 SKILL §4。

平台 `.bson` 扩展名，**内容为 JSON 数组**（非二进制 BSON）。禁止把 `identitytoken` 写入仓库或 bson。

---

## 目录

1. [⛔⛔ 字段完整性硬约束](#⛔⛔-字段完整性硬约束先读这条)  
2. [文件角色与命名](#文件角色与命名)  
3. [gateway-apis.json](#项目侧元数据推荐)  
4. [主键 ID 与脚本](#主键-id生成-bson-前必做)  
5. [步骤 1 编排结构](#步骤1-编排-bson-结构)  
6. [步骤 2 API 列表](#步骤2-api-列表-bson-结构)  
7. [responseSample](#responsesample强制调用成功返回不是模板默认值)  
8. [交付后](#交付后)

---

## ⛔⛔ 字段完整性硬约束（先读这条）

**这是本技能唯一曾导致「平台打不开编排」的根本原因，不是可选项。**

平台 Loader 反序列化按固定键集进行，**空值 / 默认值也必须显式存在**。少一个键，Loader 就抛异常，
而且**不告诉你是哪个键** —— 表现为「编排打不开」「入参不是嵌套对象」「流程设计器异常」。

### 硬指标（2026-10-15 实测，2026-10-19 复测确认）

| 对象 | 形态 | 字段数 |
|---|---|---|
| 步骤1 内部 REST 的 `P_ActionUrlConfig` | **数组** `[ {...} ]` | **109** |
| 步骤2 API 列表的 `P_ActionUrlConfig` | **对象** `{ ... }` | **109** |
| `paramsDocs` 每个节点 | 对象 | **16**（Object/Array 型多一个 `children` = 17） |

⛔ **两种形态别搞混**：步骤1 是数组、步骤2 是对象。写错形态平台同样打不开。

### `paramsDocs` 节点 16 键（实测自平台导出件，键集与顺序固定）

```json
["id","fieldName","fieldId","fieldType","hidden","breakFlag","required",
 "sampleValue","enCode","order","in","errorCode","maxLength","minLength",
 "deprecated","sortNum"]
```

- Object / Array 型节点追加 `"children": []`
- ⛔ **不是** `fieldId/fieldName/fieldType` 这种 3 键精简形态 —— 那会让平台读不出嵌套
- ⛔ 也不是 `description` / `defaultValue` / `isArray` / `state` 那套名字（那是另一类对象的键，别混）

### 生成脚本必须这么做

1. **从平台真实导出件 deep-copy**（技能内 `example_gateway_step1/step2` 是旧样例，**字段不全**），
   再覆盖本接口的值 —— ⛔ **绝不手写字段清单、绝不「只写用得到的字段」**。
2. 写盘后**必须**跑结构断言，**返回码 0 才算交付**：

```bash
python .AGENTS/skills/api-interface/references/Test-GatewayBsonStructure.py \
    BP_{method}_{yyMMddHHmm}.bson WG_{method}_{yyMMddHHmm}.bson
```

断言覆盖：`P_ActionUrlConfig` 字段数（对象/数组两形态）· `paramsDocs` 每节点 16 键 · 地址口径
（BP 走 `/system_mes/`、WG 走 `/thirdparty/mes/` 且不带 `/api`）· 占位符与样例标识残留 · BP/WG `configName` 一致。

> **曾在哪炸过**：10-15 上一版 BP `P_ActionUrlConfig` 只有 56 字段、WG 62 字段（照旧样例精简而来）
> ⇒ 平台 Loader 打不开编排。补到 109 字段后才正常。**同一类陷阱**：`paramsDocs` 子节点只写 3~6 键
> ⇒ 界面上「入参不是嵌套对象」。

---

## 文件角色与命名

输出目录：`.AGENTS/rules/output-path-convention.md`。  
**method** = `apis[].method`（与 `mapUrl` 一致）。

| 步骤 | 仓库模板（勿直接导入） | 生成后落盘 |
|------|------------------------|------------|
| 1 ESB 编排 + 内部 REST | `example_gateway_step1_*.bson` | **`BP_{method}_yyMMddHHmm.bson`** |
| 2 Thirdparty 列表 | `example_gateway_step2_*.bson` | **`WG_{method}_yyMMddHHmm.bson`** |

脚本 **必须** dot-source `Get-GatewayBsonOutputPaths.ps1` 并调用 `Get-GatewayBsonOutputPaths`（同一时间戳）。  
不要用定时任务样例（`Task`、cron、无内部 `P_ActionUrlConfig`）。

### esbDbConnId

| 项 | 规则 |
|----|------|
| `gateway-apis.json` → `esbDbConnId` | **一律默认 `000037`**（szapitest 测试数据源），**禁止** `REPLACE_*` |
| 导入平台 | 由**人工**在 ESB「指定数据源」核对是否改为正式库；Agent **不要**追问主库/报表库 IP（主备同步，口径一致） |
| 覆盖 | 仅当平台明确要求其他 ID 时：`New-*网关Bson.ps1 -DbConnId '00xxxx'` |
| `esbDbConnLabel` | 建议：`ESB 测试数据源 (000037)；导入前人工确认指定数据源` |

---

## 主键 ID（生成 bson 前必做）

**不要手写** `ESB_FLOW_*` / `THIRDPARTY_API_*` / `SYSTEM_MES_API_*`。先调接口，再填 bson。

Token：`$env:ESB_IDENTITY_TOKEN`（API 平台或 ESB 页 F12 的 `identitytoken`）。

**环境对齐**：界面「流程编号」`ESB_FLOW_*` 必须调 **8030** `appId=esb&type=FLOW`（与 ESB 设计器同域，如 `szapitest...:8030`）。**不要**在 8020 或内网另一套地址取 FLOW，否则号码与设计器不一致。`THIRDPARTY_API_*` / `SYSTEM_MES_API_*` 走 **8020**。bson 里 `processId`、节点 `id` 为脚本本地 24 位 hex，不是平台流水号。

### 步骤1：编排 FLOW + 节点

与定时任务相同脚本，基地址 **8030**：

```powershell
$env:ESB_IDENTITY_TOKEN = '<identitytoken>'
$flow = & '.agents\skills\api-interface\references\New-EsbScheduleIds.ps1' -NodeCount 5
# $flow.configId  → ESB_FLOW_*  → ModelConfig.configId
# $flow.processId → 24 hex      → ModelConfig.processId / id，各节点 processId，内部 ActionUrl.processId
# $flow.nodeIds   → 5 条        → 开始/结束/SQL/路由/路由 的 id（顺序：E00001、E00002、T00001、R00001、R00002）
```

内部 REST 的 `configId`（`SYSTEM_MES_API_*`）走 **8020**：

```powershell
$mes = & '.agents\skills\api-interface\references\New-ApiListIds.ps1' -AppId system_mes
# $mes.configId → SYSTEM_MES_API_* → 步骤1 P_ActionUrlConfig.configId
# $mes.id       → 24 hex           → 步骤1 P_ActionUrlConfig.id
# $mes.extraHexIds → outputParamsDocs[].id
```

若 `appId=system_mes` 调用失败：**问用户**，不要编造流水号。

### 步骤2：对外 API 列表（用户指定）

```powershell
$list = & '.agents\skills\api-interface\references\New-ApiListIds.ps1'
# 默认 AppId=Thirdparty, Type=API, BaseUrl=https://szapitest.szmtc.com.cn:8020
# $list.configId → THIRDPARTY_API_* → P_ActionUrlConfig.configId
# $list.id       → 24 hex           → P_ActionUrlConfig.id
```

等价 HTTP（**不要**把 token 写进技能调用记录以外的文件）：

```http
GET https://szapitest.szmtc.com.cn:8020/api/rest/core/serialnumber/new?appId=Thirdparty&type=API
Header: identitytoken: <登录 token>
Accept: application/json
```

响应：`{ "serialNumber": "THIRDPARTY_API_..." }` → 只填 **configId**。  
`P_ActionUrlConfig.id` 仍是 24 位 hex，用脚本的 `id`，不要把 serialNumber 填进 `id`。

| 字段 | 来源 |
|------|------|
| 步骤1 `ESB_FLOW_*` | `New-EsbScheduleIds.ps1` → `configId`（8030，`appId=esb&type=FLOW`） |
| 步骤1 `processId` / 节点 `id` | 同上 `processId` / `nodeIds` |
| 步骤1 `SYSTEM_MES_API_*` | `New-ApiListIds.ps1 -AppId system_mes` → `configId` |
| 步骤2 `THIRDPARTY_API_*` | `New-ApiListIds.ps1`（默认 Thirdparty）→ `configId` |
| 各 ActionUrl `id`、outputParamsDocs `id` | 脚本 24 位 hex（见下表，**禁止**只换 `configId` 留样例 hex） |

### 24 位 hex 替换清单（网关）

| 步骤 | 字段 | 来源 |
|------|------|------|
| 1 内部 REST | `P_ActionUrlConfig.id` | `New-ApiListIds.ps1 -AppId system_mes` → `id` |
| 1 内部 REST | `outputParamsDocs[].id`（如 ReturnMessage/ReturnValue） | 同上 → `extraHexIds[]` |
| 2 API 列表 | `P_ActionUrlConfig.id` | `New-ApiListIds.ps1`（Thirdparty）→ `id` |
| 2 API 列表 | `outputParamsDocs[].id`（state/errcode/msg/data/transactionId） | 同上 → `extraHexIds[]` 按样例顺序替换 |
| 2 API 列表 | `responseSample` 内 `transactionId` | `extraHexIds` 中单独一条（样例 `6a9645cab016b4674fc6db41` 须换掉） |

`pNodeId` 画布键保持：**`E00001`、`E00002`、`T00001`、`R00001`、`R00002`**。SQL 节点与定时任务一样从 `T00001` 起号（`extAttribute` 用 `$.T00001.data`）。

---

## 步骤1 编排 bson 结构

JSON 数组 **2 个元素**（第二个对象同时带节点和内部 REST，不是 3 段）：

```json
[
  { "P_ESBProcessModelConfig": { } },
  {
    "P_ESBProcessNodeConfig": [ "开始", "结束", "执行SQL", "路由", "路由" ],
    "P_ActionUrlConfig": [ { } ]
  }
]
```

从步骤1样例复制后替换：

| 位置 | 字段 | 规则 |
|------|------|------|
| ModelConfig | `configName` / `remark` | `{短名前缀}_{功能中文名}` — **必须改掉样例里的 `总装_亚马逊AUTOTEST抽测更新` 等模板名**（步骤1 ModelConfig + 内部 ActionUrl、步骤2 API 列表 `configName` 都要一致） |
| ModelConfig | `configId` | **FLOW 脚本 → configId** |
| ModelConfig | `processId` / `id` | **FLOW 脚本 → processId** |
| ModelConfig | `categoryId` | 保持 `ESB_CATEGORY_240927002`（网关编排分类，不是定时任务的 `240927009`） |
| ModelConfig | `executeServer` | **`SingleServer`**（不要 `Task`） |
| ModelConfig | `expression` | **不要加 cron**（样例无此字段） |
| ModelConfig | `state` | 保持样例 `"2"` |
| ModelConfig | `compensateRule` | 保持 `5,15,30,60,120` |
| ModelConfig | `createTime` / `editTime` | 当前 `yyyy-MM-dd HH:mm:ss` |
| ModelConfig | `creator` / `editor` / `creatorName` / `editorName` | **`1003153` / `熊思思`**（四字段一致；写盘前调 `Set-BsonOwnerAuditFields.ps1`） |
| 每个 Node | `id` | **nodeIds[]**，顺序开始/结束/SQL/路由/路由 |
| 每个 Node | `processId` | 与 ModelConfig `processId` 相同 |
| SQL 节点 | `pNodeId` | **`T00001`** |
| SQL 节点 | `dbConnId` | 填平台「指定数据源」的 **ID**（如 `000037`）。界面显示名示例：`总装MES测试库112服务器 (000037)` — **只写在变更说明/ gateway-apis.json 的 `esbDbConnLabel`，bson 里仍是 `dbConnId` 字段** |
| SQL 节点 | **`sqlCode`** | 见下，参数用 `${$.http.{字段}}` |
| SQL 节点 | `responseData` | 保持 `"1"` |
| 内部 ActionUrl | `configName` | 与 ModelConfig 同名 |
| 内部 ActionUrl | `configId` | **`SYSTEM_MES_API_*`** |
| 内部 ActionUrl | `mapUrl` | `/system_mes/{方法英文名}` |
| 内部 ActionUrl | `beanId` / `beanMethodName` | `ESBExecuteProcessRest` / `startProcess` |
| 内部 ActionUrl | `configType` / `source` / `appId` | `REST` / `ESB` / `system_mes` |
| 内部 ActionUrl | `extAttribute` | **`$.T00001.data`** |
| 内部 ActionUrl | `processId` | 与编排 `processId` 相同 |
| 内部 ActionUrl | `id` | 24 hex（`New-ApiListIds -AppId system_mes` 的 `id`） |
| 内部 ActionUrl | `paramsDocs` / `requestBodySampleStr` | 与存储过程**入参**一致（不含 OUTPUT） |
| 内部 ActionUrl | `responseSample` | **本接口调用成功**的完整包装，见下方专节。禁止沿用样例 `TEST_YMX_OBA` 文案 |
| 内部 ActionUrl | `outputParamsDocs` | 与成功时 SQL 结果列一致（查询=业务列；写入=`ReturnMessage`+`ReturnValue=0`），id 用 extraHexIds；禁止留样例失败文案 |

`processModel` 从步骤1样例复制，节点 key 保持 `T00001`，路由 `E00001→T00001→E00002`。

### sqlCode（网关）

按**已生成存储过程的真实参数**写。HTTP 体字段用 `${$.http.{FieldId}}`，FieldId 与 `paramsDocs.fieldId`、`requestBodySampleStr` 键名一致。

```sql
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @ReturnValue INT;

EXEC @ReturnValue = dbo.{过程名}
    @returnMessage = @returnMessage OUTPUT,
    @ActionType = N'${$.http.ActionType}',
    @PostCode = N'${$.http.PostCode}',
    @LotSN = N'${$.http.LotSN}',
    … /* 过程其余业务入参均 ${$.http.字段}，与 paramsDocs 一致 */;

SELECT  @returnMessage AS ReturnMessage, @ReturnValue AS ReturnValue;
```

规则：

- 过程名、参数名、OUTPUT 与仓库 `.sql` 一致  
- **禁止**在 `sqlCode` 写死 `@ActionType` / `@PostCode` 等业务值；过程有多少业务入参（除 OUTPUT），Body + `paramsDocs` + `sqlCode` 就要多少个 `${$.http.xxx}`  
- 写入 JSON 前转义换行和引号  
- 不要塞 14 个 Orbit 系统参数  

### ⛔⛔ `paramsDocs` 节点信封（嵌套入参必读）

平台用 **`children`** 表达嵌套对象。**每一个节点**（含任意深度的 `children`）都必须是
**同一套 16 字段信封**，且 **key 顺序一致**：

```
id / fieldName / fieldId / fieldType / hidden / breakFlag / required / sampleValue /
enCode / order / in / errorCode / maxLength / minLength / deprecated / sortNum
```

若有子字段，`children` **追加在 `sortNum` 之后**：

```
{ …16 字段…, "sortNum":1, "children":[…] }
```

⛔ **两个 id 规则不同，别搞混**：

| 层级 | `id` 取值 |
|---|---|
| **顶层**（`paramsDocs` 直接元素） | **序号字符串** `"0"` / `"1"` / `"2"` … 按数组下标 |
| **子节点**（任意深度 `children`） | **独立 24 位小写 hex**（形如 Mongo ObjectId），**全局唯一**，与顶层序号无关 |

⛔⛔ **严禁**把子节点写成 `{fieldId, fieldName, fieldType}` 这类精简形态 ——
平台设计器会**读不出嵌套结构**（曾实测：子节点只有 3~6 键 ⇒ 界面上"入参不是嵌套对象"、
流程设计器打开异常）。这一条与「`P_ActionUrlConfig` 必须 109 字段」是同一类陷阱：
**空值/默认值也必须显式存在**。生成脚本须加**结构断言**（逐节点比对 16 键同序 + 子 id 唯一），
不合格即 `throw`。

> 权威底本：平台真实导出件（含 `Object`/`Array` 嵌套、8 层深度、451 节点）。
> 本仓库留存副本 ⇒ `10-Projects/szmtc-tv-test/dev/mtc-temp-save/ref/`。

---

## 步骤2 API 列表 bson 结构

JSON 数组 **1 个元素**，`P_ActionUrlConfig` 是**对象**（不是数组）：

```json
[
  { "P_ActionUrlConfig": { } }
]
```

### ⛔⛔ 底本只能是 `references/example_gateway_step2_API列表.bson`

**禁止拿供应商 / 客户的真实导出件当底本改写。** 他们导出的那条是「供应商侧接口」，
出参就是上游原始格式 `code` / `msg` / `data`，**没有网关信封**；拿它当底本改
`configName` / `mapUrl` 出来的 `WG_` 件，出参树、`responseSample` 全是别人的契约。

2026-11-04 实例（易维联两条 `THIRDPARTY_API_261030007` / `261102001`）：底本取的是供应商
`ref-API列表_温湿度接口实时数据回传_真实导出.json`，四处硬伤一次性带进来 ——

| 症状 | 判别方法 |
|---|---|
| 顶层是 `code`/`msg`/`data`，没有 `state`/`errcode`/`transactionId` | 数 `outputParamsDocs` 顶层 `fieldId` |
| `dataList` 子字段跟接口无关（两件字段表**完全相同**） | 两件 `dataList.children` 的 `fieldId` 列表逐项比 |
| `data` 少一层（真实 `$.data.data.dataList`，件里只写 `data.dataList`） | 拿 `responseSample` 按过程解析路径跑一遍 |
| 出参树 / `responseSample` / `failResponseSample` 三者格式互相矛盾 | 看 `failResponseSample` 是不是网关信封、另两个是不是上游格式 |

`Test-GatewayBsonTemplateLeak.ps1` **查不出这一类**（它的 bad 列表只有 YMX 文案）。
出件后必须另加自检：`outputParamsDocs` 顶层 `fieldId` 序列 == `['state','errcode','msg','data','transactionId']`。

出参错了，**入参通常一起错**，同样四处：`id` 全 `"0"`（应为数组下标）、`in` 全 `query`（POST body 应为 `body`）、
`sortNum` 全 `1`（应递增）、`required` 全 `false`（应按接口文档标必传）。
一次性体检脚本 ⇒ `15-Tasks/2026-10-28-1weilian-pull/gen/check_wg_format.py`（13 项，退出码非 0 即有错）。

构造器可复用 ⇒ `15-Tasks/2026-10-28-1weilian-pull/gen/gw_envelope.py`。

从步骤2样例复制后替换：

| 字段 | 规则 |
|------|------|
| `configName` | 与步骤1 同名 |
| `configId` | **`New-ApiListIds.ps1` → configId**（`THIRDPARTY_API_*`） |
| `id` | **脚本 → id**（24 hex） |
| `mapUrl` | `/thirdparty/mes/{方法英文名}`（与步骤1 方法名相同，前缀不同） |
| `backendUrl` | **等于步骤1 的 mapUrl**（`/system_mes/{方法英文名}`） |
| `beanId` / `beanMethodName` | `ServiceRegisterRest` / `redirectUrl` |
| `configType` / `source` / `appId` | `REG` / `GATEWAY` / `Thirdparty` |
| `registerFlag` | `1` |
| `methodType` | `POST` |
| `processId` | **空字符串**（对外列表不绑 ESB processId） |
| `paramsDocs` / `requestBodySampleStr` | 与步骤1 业务入参一致 |
| `responseSample` | **本接口调用成功**的返回，见下方专节；`transactionId` 用 extraHexIds 单独一条换掉样例值 |
| `failResponseSample` | 保持平台失败包装即可（`state:false` / `errcode:500`） |
| `outputParamsDocs` | 保持平台字段 `state/errcode/msg/data/transactionId`；**`data.children` 改成本过程成功结果列**（查询=SELECT 列；写入=`ReturnMessage`+`ReturnValue`） |
| `createTime` / `editTime` | 当前时间 |
| `creator` / `editor` / `creatorName` / `editorName` | **`1003153` / `熊思思`**（与步骤1 相同；写盘前 `Set-BsonOwnerAuditFields.ps1`） |

总装样例可保持（其他事业部未提供则问用户）：

| 字段 | 总装样例值 |
|------|------------|
| `categoryId` | `THIRDPARTY_CATEGORY_220824005` |
| `businessClassIds` | `BU_AREA_220825002` |
| `parentId` | `6a7692e609c8c94f166d6b5e` |
| `bindServicesConfigId` | `63155a2911eb216cae787611` |
| `loadBalanceId` | `WeightRandomServer` |
| `visibleUserIds` | `sdx01` |
| `authType` | `1` |

---

## responseSample（强制：调用成功返回，不是模板默认值）

步骤1 内部 REST、步骤2 API 列表的 `responseSample` **都是本接口 HTTP 调用成功后的返回样例**。从 `example_gateway_step1/step2` 复制后 **必须整段替换**，不得把样例里的写号成功文案留着当默认值。

平台包装保持：

```json
{
  "state": true,
  "errcode": 200,
  "msg": "",
  "data": [ /* 本过程成功时网关 data，见下 */ ],
  "transactionId": "<本次 extraHexIds 替换后的值>"
}
```

`data` 怎么填：

| 过程类型 | `data` 内容 | 错误示例（禁止） |
|----------|-------------|------------------|
| **查询**（过程自身 `SELECT` 业务结果集） | 1～3 行真实成功列，列名与过程输出一致 | 仍写 `ReturnMessage`/`ReturnValue` 或 YMX 文案 |
| **写入/提交**（sqlCode 最后 `SELECT @ReturnMessage, @ReturnValue`） | `{ "ReturnMessage": "本过程成功时的 MES: 文案", "ReturnValue": 0 }` | 样例 `MES:条码 TEST_YMX_OBA_001 的 obaTested 已是 TRUE，无需修改` |

`outputParamsDocs` 的 `sampleValue` / `fieldValue` 同步用**成功**样例：

- 查询：与 `data` 列一致（拉别、订单号、数量等）
- 写入：`ReturnMessage` = 本过程成功 `MES:` 文案，`ReturnValue` = `0`
- 禁止留 `MES:未找到条码 TESTLOT00002…`、`ReturnValue=-1` 这种样例失败文案

写盘前用 `references/Test-GatewayBsonTemplateLeak.ps1` 自检；命中 `TEST_YMX_OBA_001` / `TESTLOT00002` / `obaTested 已是 TRUE` 则失败。

`gateway-apis.json` 必填：

| 字段 | 含义 |
|------|------|
| `apis[].responseSample` | 对象：`state/errcode/msg/data`（可不含 `transactionId`，生成脚本写入） |
| `apis[].outputParams` | 成功结果列：`fieldId`/`fieldName`/`fieldType`/`sample` |

缺任一字段 **禁止生成 bson**。生成脚本必须 `Replace-JsonStringField responseSample`，步骤1 替换 `outputParamsDocs`，步骤2 替换 `data.children`。

---

## 方法英文名

`{方法英文名}` 简短、稳定，与存储过程职责对应（如 `YMXUploadFileSetObaTested`）。  
步骤1 `mapUrl`、步骤2 `mapUrl`、步骤2 `backendUrl` **共用这一个名字**，只改前缀 `/system_mes/` vs `/thirdparty/mes/`。

---

项目生成脚本（如 `New-*网关Bson.ps1`）应 **直接调用** `New-EsbScheduleIds.ps1` / `New-ApiListIds.ps1`，未设置 `ESB_IDENTITY_TOKEN` 时 **报错退出**，不得写入 `REPLACE_*` 占位 configId。

写文件前 **必须** dot-source `Set-BsonOwnerAuditFields.ps1` 并对最终 JSON 调用一次（覆盖样例里混用的他人工号）。可选自检：输出中不得含 `"creator":"1002531"` 等与默认负责人不一致的残留。

---

## 项目侧元数据（推荐）

功能目录下放 `gateway-apis.json`，至少包含：

| 字段 | 含义 |
|------|------|
| `esbDbConnId` | SQL 节点 `dbConnId`；**默认 `000037`**；**禁止** `REPLACE_*` |
| `esbDbConnLabel` | 平台显示名 + 提醒「导入前人工确认数据源」 |
| `apis[].method` | 接口英文名；用于 **`BP_` / `WG_` 文件名** 与 URL 路径 |
| `apis[].configName` / `remark` | 业务中文名，生成 bson 时**全文替换**样例 `configName`，勿只改 URL |
| `apis[].responseSample` | 本接口**调用成功**的 HTTP 包装（`data`=本过程成功结果） |
| `apis[].outputParams` | 成功结果列，写入步骤1 `outputParamsDocs` 与步骤2 `data.children`；**列名与过程成功 SELECT 一致** |
| `apis[].params` | 与过程入参一致（**勿**在 json 保留已删除的过程参数） |

`New-ApiListIds.ps1` 的 `-ExtraHexCount`：用 **`Get-GatewayOutputParamCount`** 统计条数（勿用 `@($outputList).Count`，`ArrayList` 会误判为 1），再 **`[int][Math]::Max(12, 条数 + 2)`**（脚本内内联，勿赋 0）。

新建功能可复制模板：`references/example_gateway-apis.json`。

生成脚本应对输出做 JSON 校验，并拒绝残留 `亚马逊AUTOTEST`、`YMXUploadFileSetObaTested`、`TEST_YMX_OBA_001`、`TESTLOT00002` 等样例标识（`Test-GatewayBsonTemplateLeak.ps1`）。

---

## ⛔ 签名 / 哈希校验：SQL Server 与平台的编码口径不同

对接任何「供应商算 sign、我们校验」的接口都要先过这一条，**否则签名长度对、结果始终不匹配**。

| 环节 | 字节口径 |
|---|---|
| 平台（Java / JS / 各家 SDK） | **UTF-8** |
| T-SQL `HASHBYTES('SHA2_256', @x)` 且 `@x` 是 `NVARCHAR` | **UTF-16LE** |

⇒ 同一个字符串，两边算出**两个不同的哈希**。现象：长度都是 64 位 hex、肉眼看着都"像"，
但比对永远失败，且不会有任何报错。

**修法**：哈希前把参数显式转成单字节类型

```sql
DECLARE @h VARBINARY(32) = HASHBYTES('SHA2_256',
    CAST(@SecretKey AS VARCHAR(200)) + CAST(@CurrentTime AS VARCHAR(50)));
DECLARE @sign CHAR(64) = LOWER(CONVERT(VARCHAR(64), @h, 2));
```

- ⛔ 参与哈希的串里**不能有非 ASCII**（中文/全角）—— `VARCHAR` 会按当前排序规则映射，
  结果随实例配置漂移 ⇒ **密钥必须纯 ASCII**
- 判据不能只看长度：比 `LOWER(CONVERT(...))` 的完整 64 位 hex
- 平台侧若给的是**大写** hex，比对前统一 `LOWER()`

> **曾错**：第一版直接用 `HASHBYTES('SHA2_256', @SecretKey + @CurrentTime)`（两者都是 `NVARCHAR`）
> ⇒ UTF-16LE 字节流、签名永远不匹配。改成先 `CAST(... AS VARCHAR)` 才对。

---

## 交付后

说明：步骤1 在 ESB 编排导入，步骤2 在 API 列表/网关导入；AI 不连平台发布。  
`processId` 导入后可能被平台改写。步骤2 必须在步骤1 的内部 URL 已存在（或同批导入且 `backendUrl` 指向步骤1 `mapUrl`）。

---

## ⛔ ESB 流程侧（步骤1）节点的类型口径 —— 与 WG 侧相反

**权威底本 = 技能内 `example_schedule_*.bson`**（步骤1 的样例），⛔ **不可只拿 WG 的 ref 去对齐流程侧**
（曾经只对 WG ⇒ 流程侧字段类型从未验证过，导入后设计器点开 SQL 节点配置弹窗直接打不开）。

流程侧与 WG 侧口径**不同**，别互相套用：

| 项 | 流程侧（步骤1 `P_ESB*`） | WG 侧（步骤2 `P_ActionUrlConfig`） |
|---|---|---|
| 布尔 / 序号 | **全字符串**（`"false"` / `"0"` / `"1"`） | 真实件原样（bool / int 就是真 bool / int） |
| 空集合字段 | `"[]"`（**不是 `""`**） | 同左 |
| 节点 `_id` | 唯一 ObjectId 形态 | — |

流程侧必查项：
- SQL 节点 `exportParams` / `tableColumns`：**空集必须写 `"[]"`**，写 `""` ⇒ `JSON.parse` 崩、弹窗打不开
- `exceptionAssert` = `"0"`
- 路由节点 `pNodeName` = `"NO_SHOW"`；开始节点 `gatewayType` = `"1"`；结束节点 `processEndType` = `"3"`
- `async` / `asyncFlag` / `appendFlag` / `order` 等：**一律字符串**
- ModelConfig 的 `eventType` / `repeatGenerationTask` 用字符串；`eventBody` 换行须**字面 `\n`**

排查手法：拿真实导出件与自产件做**逐字段 diff**（类型也要比），不要只比字段名集合。

