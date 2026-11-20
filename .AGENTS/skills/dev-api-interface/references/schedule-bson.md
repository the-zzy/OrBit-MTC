# 定时任务编排（ESB bson）

> **Agent 入口**：[`../SKILL.md`](../SKILL.md) §2 交付 A。与 API 网关（BP/WG）**不是**同一条路径。

平台 `.bson` 为 **JSON 数组**（非二进制 BSON）。  
样例：`example_schedule_总装_海外海尔出货生产数据回传.bson`  
结构：`[ { P_ESBProcessModelConfig }, { P_ESBProcessNodeConfig: [开始, 结束, 执行SQL, 两条路由] } ]`

## 何时生成

仅 **定时任务编排**（MES 自己定时跑）。  
API 网关不要用本文件，走 `gateway-bson.md`（`SingleServer`、无 cron、带内部 `P_ActionUrlConfig`）。

## 文件名与目录

```
{事业部中文名}/开发/{功能中文名}/{短名前缀}_{功能中文名}_{yyMMddHHmm}.bson
```

短名前缀与 MCP 环境对应（文件名里的「总装」= 深圳总装库）：

| 短名前缀 | 环境 | MCP | dbConnId（bson SQL 节点） |
|----------|------|-----|---------------------------|
| 总装 | 深圳总装 | sqlserver-SZ_TV | 测试 **`000037`**；正式导入前人工确认数据源 |

其他事业部：json/变更说明默认可写 **`000037`** 生成测试 bson；**不要**向用户追问库 IP。

## 主键 ID 生成（生成 bson 前必做）

**不要手写** `ESB_FLOW_yyMMdd001` 或随意拼 24 位 hex。先生成 ID，再填入 bson。

### 脚本（仓库内）

路径：`.AGENTS/skills/dev-api-interface/references/New-EsbScheduleIds.ps1`

```powershell
# 从 ESB 编排页 F12 复制 identitytoken，勿提交到 Git
$env:ESB_IDENTITY_TOKEN = '<identitytoken>'

# 默认连 szapitest；正式环境可 -BaseUrl 'https://...'
$ids = & '.agents\skills\dev-api-interface\references\New-EsbScheduleIds.ps1' -NodeCount 5

$ids.configId    # 例：ESB_FLOW_260914007  ← 平台流水号
$ids.processId   # 例：062ed3067ba7fbf054376da1
$ids.nodeIds     # 5 条，对应 开始/结束/SQL/路由1/路由2 的 id 字段
```

Agent 生成或更新 bson 时：**应执行该脚本**（或等价的 `Invoke-RestMethod` + 脚本内随机 hex 逻辑），用返回值替换下文字段。

### 平台接口（与脚本一致）

```http
GET {BaseUrl}/api/rest/core/serialnumber/new?appId=esb&type=FLOW
Header: identitytoken: <登录 token>
Accept: application/json
```

响应示例：

```json
{ "serialNumber": "ESB_FLOW_260914007" }
```

| 字段 | 来源 |
|------|------|
| `configId` | 上表接口 `serialNumber`（`type=FLOW`） |
| `processId`、ModelConfig 的 `id` | 脚本生成的 **24 位小写 hex**（12 字节随机，与导出 bson 形态一致） |
| 各 `P_ESBProcessNodeConfig.id` | `nodeIds[0..4]`，与 `processId` 同前缀、末字节递增（与样例 bson 规律一致） |
| 各节点的 `processId` | 与 ModelConfig `processId` **相同** |
| `pNodeId` | 画布键：**`E00001`、`E00002`、`T00001`、`R00001`、`R00002`**（不调流水号接口） |

SQL 节点一律从 **`T00001`** 起号。仓库里定时任务样例用了 `T00002`，那是画布上拖了两个 SQL 节点后删掉 `T00001` 的例外；**新生成时不要照抄 `T00002`**，`processModel` 与路由也改成 `E00001 → T00001 → E00002`。

说明：`type=NODE` 等返回 `ESB_NODE_*` 业务号，**不是** bson 里节点 `id` 的 24 位 hex，勿混用。

正式/测试环境 `BaseUrl` 以用户 ESB 编排地址为准（测试常见 `https://szapitest.szmtc.com.cn:8030`）。

## 必须改的字段

从样例复制后替换：

| 位置 | 字段 | 规则 |
|------|------|------|
| ModelConfig | `configName` / `remark` | `{短名前缀}_{功能中文名}` |
| ModelConfig | `configId` | **`New-EsbScheduleIds.ps1` → `configId`** |
| ModelConfig | `expression` | cron，默认 `0 0 9 * * ?`（每天 9 点）；用户指定则用用户的 |
| ModelConfig | `processId` / `id` | **脚本 → `processId`**；各节点 `processId` 与之相同 |
| 每个 Node | `id` | **脚本 → `nodeIds[]`**（顺序：开始、结束、SQL、路由、路由） |
| ModelConfig | `createTime` / `editTime` | 当前时间 `yyyy-MM-dd HH:mm:ss` |
| ModelConfig | `creator` / `editor` / `creatorName` / `editorName` | **`1003153` / `熊思思`**（写盘前 `Set-BsonOwnerAuditFields.ps1`） |
| sql 节点 | `pNodeId` | **`T00001`**（样例若为 `T00002` 要改过来，含 `processModel` 与路由 `sourceId`/`targetId`） |
| sql 节点 | `dbConnId` | 上表；总装=`000037` |
| sql 节点 | **`sqlCode`** | 调用本需求存储过程的 T-SQL，见下 |

保持样例即可：`categoryId=ESB_CATEGORY_240927009`、`applicationId=system_mes`、`executeServer=Task`、开始→执行SQL脚本→结束。  
`processModel` 与路由按 **`T00001`** 写，不要保留样例里的 `T00002`。

`sqlCode` 写入 JSON 前要做 JSON 转义（换行、引号）。

## sqlCode 怎么填

按**已生成存储过程的真实参数**写，不要抄样例里的过程名。

模板：

```sql
DECLARE @returnMessage NVARCHAR(MAX), @ReturnValue INT;
-- 按过程入参 DECLARE 并赋默认值（日期常用 GETDATE()）
EXEC @ReturnValue = dbo.{过程名}
    @returnMessage = @returnMessage OUTPUT
    {, @业务参数 = @业务参数};
SELECT @returnMessage AS ReturnMessage, @ReturnValue AS ReturnValue;
```

样例（总装海尔，过程已有 `@I_ReturnMessage` 时跟过程走）：

```sql
DECLARE @I_ReturnMessage NVARCHAR(MAX), @ReturnValue INT;
DECLARE @ShipDateEnd DATE = GETDATE();
EXEC @ReturnValue = dbo.DataExport_DailyPush
    @I_ReturnMessage = @I_ReturnMessage OUTPUT,
    @ShipDateEnd = @ShipDateEnd,
    @DryRun = 0;
SELECT @I_ReturnMessage AS ReturnMessage, @ReturnValue AS ReturnValue;
```

规则：

- `EXEC` 的过程名、参数名、OUTPUT 与仓库里的 `.sql` 一致  
- 编排默认定时跑，不要用会改生产数据的 DryRun 调试值，除非用户要求  
- 不要把 14 个 Orbit 系统参数硬塞进 sqlCode  

## 写盘前审计人

与网关相同：dot-source `Set-BsonOwnerAuditFields.ps1`，对最终 JSON 调用 `Set-BsonOwnerAuditFields -Json $json` 后再 `WriteAllText`。  
定时任务样例 `example_schedule_*.bson` 曾出现 `creator`/`editor` 工号不一致，**不能**只改其一。

## 交付后

说明：文件需在 ESB 编排平台导入；`processId` 导入后可能被平台改写。AI 不连平台发布，也不在库上执行编排。
