---
name: api-interface
description: >-
  交付对外 API（非看板 WebAPI_）：设备 GET/SUBMIT、HTTP 查询走 API 网关 BP+WG bson，
  ESB 定时任务走单 bson。产出 SQL、gateway-apis.json 和执行生成脚本。
  用于 API、ADC、设备对接、GET/SUBMIT、Thirdparty、sqlCode、ESB 编排。
version: "2.1.1"
agent_created: true
---

# 对外 API 接口（api-interface）

## 阅读说明（人看）

- **只有两种交付**，不是三种：  
  **① 定时任务**（MES 自己按时跑）→ 1 个编排 bson  
  **② API 网关**（HTTP 调 MES，**含设备口 GET/SUBMIT、报表查询、供应商接口**）→ **BP + WG** 两个 bson  
- 设备口 **不是** 单独一类；只是存储过程写法不同（`ActionType`/`PostCode`），**bson 与导入流程与查询 API 相同**。  
- 默认 `esbDbConnId` = **`000037`**；导入 ESB 时 **人工** 在「指定数据源」确认，Agent 不追问主备库。

---

## 1. 边界

| 走本技能 | 不走本技能 |
|----------|------------|
| 对外 HTTP / 设备经网关、ESB 定时编排 | 看板 `WebAPI_*` → 技能 `kanban-echart` |
| 过程仅业务参数（无 Orbit 14 参） | 把 `WebAPI_` 当对外 API |

目录：`.AGENTS/rules/output-path-convention.md`  
SQL：`.AGENTS/rules/stored-procedure-rules.md`

---

## 2. 两种交付（二选一）

| 交付 | 什么时候 | bson | 详细文档 |
|------|----------|------|----------|
| **A. 定时任务** | cron / Job / 定时回传 | **1 个**编排 bson | `references/schedule-bson.md` |
| **B. API 网关** | 任何 HTTP 调用（**设备 GET/SUBMIT、查询、提交**） | **`BP_{method}_*.bson`** + **`WG_{method}_*.bson`** | `references/gateway-bson.md` |

**B 的调用链（设备与查询相同）**

```text
POST /thirdparty/mes/{method}  →  /system_mes/{method}  →  ESB SQL  →  存储过程
```

---

## 2.1 过程依赖新物理表时（先于 §3）

若本次在 API/设备存储过程中 **`INSERT` 尚未存在的业务表**（含追溯/日志表），**必须先完整 Read** 技能 [`create-table`](/.AGENTS/skills/create-table/SKILL.md)，交付 `{表名}_MTable.sql`，再写或 `ALTER` 过程。  
**不要**因任务表述为「改 `API_*` / 填充报告」而跳过建表技能。

---

## 3. API 网关交付步骤（B，Agent 必做）

| # | 动作 |
|---|------|
| 1 | 存储过程 + `_TestCase.sql` + `变更说明.md`（**有新表时**：先 MTable，再过程） |
| 2 | 同目录 `gateway-apis.json`（复制 `references/example_gateway-apis.json`） |
| 3 | `params` / `outputParams` 与过程 **完全一致**（删参则 json 同步删） |
| 4 | `esbDbConnId`: **`"000037"`**；禁止 `REPLACE_*` |
| 5 | `New-*网关Bson.ps1`（dot-source `Get-GatewayBsonOutputPaths.ps1`；可复制现有项目脚本） |
| 6 | **执行脚本** → 必须出现 **BP_** 与 **WG_** 两个文件 |
| 6.1 | **⛔ 结构断言（不通过不得交付）**：`python references/Test-GatewayBsonStructure.py BP_*.bson WG_*.bson`，**返回码 0 才算过**。校验 `P_ActionUrlConfig` = 109 字段（BP 数组 / WG 对象两种形态）、`paramsDocs` 每节点 16 键、地址口径、占位符残留、`configName` 一致 |
| 7 | 变更说明：编排名、`/thirdparty/mes/{method}`、导入前人工确认数据源 |

> ⛔⛔ **`P_ActionUrlConfig` 109 字段是本技能头号炸点** —— 少一个空字段平台 Loader 就打不开编排，且不报是哪个。
> 详见 [`references/gateway-bson.md`](references/gateway-bson.md) §字段完整性硬约束。
> ⛔ 旧样例 `example_gateway_step1/step2` **字段不全**，不能当字段清单用；要从平台真实导出件 deep-copy。

> **§3 整表仅适用于 B（API 网关）。** 选 **A 定时任务** 时 **不要** 做第 2、5、6 步（无 `gateway-apis.json`、无 BP/WG、无 `New-*网关Bson.ps1`）。

## 3A. 定时任务交付步骤（A）

| # | 动作 |
|---|------|
| 1 | 存储过程 + 变更说明（按任务需要） |
| 2 | 按 `schedule-bson.md` 拼 **1 个**编排 bson（`executeServer=Task`、cron 等） |
| 3 | 跑 `New-EsbScheduleIds.ps1` 取 `ESB_FLOW_*` / 节点 hex，**禁止手写** |
| 4 | SQL 节点 `dbConnId` 默认可 **`000037`**；导入前人工确认数据源 |

文件名规则见 `schedule-bson.md`（**不是** `BP_` / `WG_` 前缀）。

---

## 4. 存储过程（都在网关 SQL 里执行）

同一套 ESB 编排；差异只在 **过程命名与参数形态**：

| 形态 | 典型命名 | 参数要点 | json |
|------|----------|----------|------|
| **查询 / 报表** | `APIBP_*` | 业务筛选参；成功时 `SELECT` 结果集 | `outputParams` = 成功列 |
| **设备 / 写回** | `VADC_*` 或项目约定 | `@ActionType` GET/SUBMIT、`@PostCode`、`MES:` | 成功多为 `ReturnMessage`+`ReturnValue`；按过程填 `outputParams` |

共性：TRY/CATCH、无显式事务、CREATE/ALTER、SQL 2016、`RETURN 0/-1`；网关 **`sqlCode` 用 `${$.http.字段}`**，不写死业务值。  
编排过程备注：`-- 编排名称：{configName}`（与 json 一致）。

---

## 5. 网关 bson 速查

| 项 | 值 |
|----|-----|
| 文件名 | `BP_{method}_yyMMddHHmm.bson`、`WG_{method}_yyMMddHHmm.bson` |
| `method` | `gateway-apis.json` → `apis[].method` |
| 流水号 | 8030 `New-EsbScheduleIds.ps1`；8020 `New-ApiListIds.ps1`（禁止手写） |
| ExtraHexCount | `[int][Math]::Max(12, Get-GatewayOutputParamCount + 2)` |
| 凭据 | 环境变量 `ESB_IDENTITY_TOKEN`，或本地未跟踪 `secrets/esb-api-auth.local.json` |
| 写盘前 | `Set-BsonOwnerAuditFields.ps1`、`Test-GatewayBsonTemplateLeak.ps1` |

结构 / hex / responseSample：**`references/gateway-bson.md`**

---

## 6. 参考索引

| 文件 | 用途 |
|------|------|
| `references/README.md` | 脚本与文档一览 |
| `references/gateway-bson.md` | 网关 BP/WG 全文 |
| `references/schedule-bson.md` | 定时单 bson |
| `references/example_gateway-apis.json` | json 模板 |
| `references/Get-GatewayBsonOutputPaths.ps1` | 文件名、dbConn 校验、outputParams 条数 |
| `example_gateway_step1_*.bson` / `step2_*.bson` | 结构模板（勿直接导入） |

示例生成脚本：`tasks/<MCP名>/dev/<功能英文名>/New-<功能>网关Bson.ps1`；查询与设备 GET/SUBMIT 都是 BP/WG。

---

## 7. 禁止

- token/密码入库；bson 留样例 YMX / TESTLOT / 未改 `configName`  
- 网关 **(B)** 只交 SQL、**不跑脚本**产出 BP/WG  
- `REPLACE_*` 的 `esbDbConnId`；json 与过程不一致  
- 手写平台流水号或只换 configId 不换 hex  
- 用定时任务模板（`Task`+cron）冒充网关  
- 对外 API 加 14 个 Orbit 参；用 `WebAPI_` 前缀  
- ⛔ **跳过结构断言就交 BP/WG**；⛔ **手写或精简 `P_ActionUrlConfig` / `paramsDocs` 的字段**  
- ⛔ **签名校验把 `NVARCHAR` 直接丢进 `HASHBYTES`**（平台 UTF-8 / SQL UTF-16LE，见 `gateway-bson.md` 签名段）  
