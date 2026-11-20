# references 目录说明

**技能入口**：[`../SKILL.md`](../SKILL.md)

## 文档（按交付类型）

| 文档 | 交付 |
|------|------|
| [`gateway-bson.md`](gateway-bson.md) | **API 网关**（设备 GET/SUBMIT、HTTP 查询、提交）→ BP + WG |
| [`schedule-bson.md`](schedule-bson.md) | **定时任务** → 1 个编排 bson |

## 配置与模板

| 文件 | 用途 |
|------|------|
| [`example_gateway-apis.json`](example_gateway-apis.json) | 复制为功能目录 `gateway-apis.json` |
| `example_gateway_step1_*.bson` / `step2_*.bson` | 网关 bson **结构**模板（须脚本替换后再导入） |
| `example_schedule_*.bson` | 定时 bson 结构模板 |

## 脚本（生成 bson 时调用）

| 脚本 | 作用 |
|------|------|
| [`Get-GatewayBsonOutputPaths.ps1`](Get-GatewayBsonOutputPaths.ps1) | `BP_`/`WG_` 路径；`Assert-GatewayEsbDbConnId`；`Get-GatewayOutputParamCount` |
| [`Get-EsbApiIdentityToken.ps1`](Get-EsbApiIdentityToken.ps1) | 登录取 token |
| [`New-EsbScheduleIds.ps1`](New-EsbScheduleIds.ps1) | 8030：`ESB_FLOW_*` + 节点 hex |
| [`New-ApiListIds.ps1`](New-ApiListIds.ps1) | 8020：`SYSTEM_MES_API_*` / `THIRDPARTY_API_*` + extraHexIds |
| [`Set-BsonOwnerAuditFields.ps1`](Set-BsonOwnerAuditFields.ps1) | 统一 creator/editor |
| [`Test-GatewayBsonTemplateLeak.ps1`](Test-GatewayBsonTemplateLeak.ps1) | 拦截样例文案残留 |
| [`Test-GatewayBsonStructure.py`](Test-GatewayBsonStructure.py) | **结构完整性断言（交付必跑）**：`P_ActionUrlConfig` 109 字段（BP 数组 / WG 对象）、`paramsDocs` 每节点 16 键、地址口径、占位符、`configName` 一致；返回码 0 才算过 |
| [`Enable-EsbTlsForInternalApi.ps1`](Enable-EsbTlsForInternalApi.ps1) | 内网 TLS（被其它脚本 dot-source） |
| [`Invoke-EsbPlatformSerial.ps1`](Invoke-EsbPlatformSerial.ps1) | 流水号 HTTP（被 New-*Ids 引用） |

项目侧：`New-*网关Bson.ps1` 放在各 `事业部/开发/功能/` 下，读本地 `gateway-apis.json` 并调用上表脚本。
