---
name: mes-meta-query
description: >-
  用本地只读脚本查 MES 架构表：插件、元对象、静态事务、移动事务、查询元的字段与按钮。
  用户要查 SysPlugIn、SysMetadata、MESTxnObject、MobileObject、SysMetadataQuery、SysMetadataMethod 时用。改表、改过程、写数据不用。
---

# 架构表快速查询

架构表在所有 MES 库里结构一致，字段完全一样。表或列查不到就是环境问题，不是要换一套查法。

工具：`scripts/query_meta.ps1`。只读，复用 `db/catalog/{MCP名}` 和 `secrets/{MCP名}.env` 的连接，不输出凭据。

## 先定对象类型

拿到插件命令先看 `SysPlugIn.PluginFileName`，再选查法；不要按命令名的印象猜。

| PluginFileName | 查法 | 例子 |
|---|---|---|
| `Plugin Standard.dll` | 元对象：`SysMetadata` / `SysMetadataFieldGroup` / `SysMetadataMethod` | `KDYN` 国外CKD订单（PC） |
| `Plugin Query.dll` | 查询元：`-Action query` | `TDLQ` 任务清单 |
| `PluginMESMobile.dll` | 移动事务：`-Action mobile` | `CKDYN` CKD装箱扫描(越南)（PDA） |
| `PluginMESStaticTxn.dll` | 静态事务：`-Action txn` | `BDPB` 散件外箱打印 |

**`KDYN` 与 `CKDYN` 只差一个字母**：`KDYN` 是 PC 标准元对象「国外CKD订单」，`CKDYN` 是 PDA 移动事务「CKD装箱扫描(越南)」。拿 `KDYN` 调 `-Action mobile` 会返回空，那不是环境问题。

插件命令是定长 `char`，表里常带尾随空格（如 `KDYN `），比较时两边都 `RTRIM`。

## 调用

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 `
  -Env jiban-mes-prod -Action <动作> -Key <值>
```

`-Env` 用 `mes-db` 里的 MCP 名。输出 UTF-8 JSON。

## 动作

| 动作 | `-Key` | 返回 |
|---|---|---|
| `plugin` | 插件命令 | SysPlugIn 和 OrDroidPlugin 两边的插件行 |
| `txn` | 插件命令 | 静态事务对象、字段、按钮，一个插件多对象时全部返回 |
| `mobile` | 插件命令 | 移动事务对象、字段、按钮；PC 和 OrDroid 两边的映射都查 |
| `query` | 插件命令或 MetadataName | 查询元对象、元字段组、各组的查询条件和按钮 |
| `groups` | MetadataId | 元字段组 |
| `fields` | MetadataId | `SysMetadataQuery` 查询条件 |
| `methods` | MetadataId 或 MetadataFieldGroupId | `SysMetadataMethod` 按钮 |
| `params` | 事务对象名或 ID | 静态/移动事务对象的字段和按钮 |
| `search` | 名称片段 | 插件、元对象、静态事务、移动事务、SysObject |
| `menu` | 插件命令 | 应用 / 用户组 / 菜单组 |
| `proc` | 过程名 | `sys.sql_modules.definition` |
| `sql` | `-Sql "SELECT ..."` | 一条只读查询结果，最多 `-Limit` 行（默认 200） |

常用例子：

```powershell
# 插件命令定位
... -Action plugin -Key AGUA

# 静态事务：一次拿对象、字段、按钮
... -Action txn -Key AGUA

# 移动事务：一次拿全部页面
... -Action mobile -Key CKDYN

# 查询元：按元字段组分块，带条件和按钮
... -Action query -Key ACSN

# 只记得中文名
... -Action search -Key 锡膏

# 没有 MCP procedure 工具的库
... -Action proc -Key AlreadyCancelSNQueryDoMethod
```

## 结果怎么读

- `objects`：一个插件下的多个事务对象，按页签/页面顺序排列。
- `groups`：查询元的元字段组，每组带 `fields` 和 `methods`。
- `rows`：平铺结果。
- `error`：有错误时先看这个字段。

## 固定表结构

### 插件

| 表 | 关键列 |
|---|---|
| `SysPlugIn` | `PluginId` `PluginCommand` `PluginName` `PluginFileName` `PluginParameter` `MetadataId` |
| `OrDroidPlugin` | `OrDroidPluginId` `OrDroidPluginCommand` `OrDroidPluginName` `OrDroidPluginFileName` |

插件类型：

| `PluginFileName` | 类型 |
|---|---|
| `Plugin Standard.dll` | 标准元对象 |
| `Plugin Query.dll` | 查询元对象 |
| `PluginMESStaticTxn.dll` | 静态事务对象 |
| `PluginMESMobile.dll` | 移动事务对象 |
| `Plugin Workflow.dll` | 工作流对象 |

### 元对象和查询元

| 表 | 关键列 |
|---|---|
| `SysMetadata` | `MetadataId` `MetadataName` `MetadataDescription` `ParentMetadataId` `ObjectId` `TreeView` `SubTreeView` `MainView` `MainSave` `MainDelete` `FilterField` `IsTreeViewStyle` `IsEnterKeySupport` `IsMultiPageSupport` `ObjectScript` |
| `SysMetadataFieldGroup` | `MetadataFieldGroupId` `MetadataId` `FieldGroupName` `FieldGroupSequence` `ColumnCount` `FieldGroupHeight` `IsCollapsed` `IsHidden` |
| `SysMetadataQuery` | `MetadataQueryId` `MetadataFieldGroupId` `FieldName` `DataType` `FieldSequence` `IsValueListUsage` `ValueList` `LinkToValueListField` `IsReadOnly` `IsHidden` `IsShowTime` `ControlLine` `IsOpenFile` |
| `SysMetadataMethod` | `MetadataMethodId` `MetadataFieldGroupId` `MethodSequence` `MethodName` `SQLDoMethod` `MainViewParameter` `DialogParameter` `UDialogParameter` `IsBeforeRunningConfirm` `PromptMessage` `IsAutoRunQuery` `IsRefreshTreeView` `IsAcceptMainViewAsParameter` `IsRunSubQuery` `SubQuerySQLMethod` `SubQueryParameter` `QuerySummaryField` `QueryMargedField` `IsShowRowIndex` `IsPrintMethod` `IsPreview` `LabelFileSP` `LabelFileName` `IsShowDataSetWindow` `AccessCode` |

### 静态事务

| 表 | 关键列 |
|---|---|
| `MESTxnObject` | `MESTxnObjectId` `MESTxnObjectName` `MESTxnObjectDesc` `IsActivity` `MESTxnObjectType` `ColumnCount` `FieldWidth` `FieldSpace` `IsThirdDllUsage` `ThirdDllFileName` `DTxnSubmitTxn` `DTxnSubmitParameter` `IsDefaultMESTxn` `IsStaticRun` `IsUserUI` `IsRunObjectScript` `ObjectScript` `AccessCode` `SOPGroupId` |
| `MESTxnObjectParameter` | `MESTxnObjectParameterId` `MESTxnObjectId` `TxnParameterName` `DataType` `ParameterSequence` `IsValueListUsage` `ControlLine` `ValueList` `LinkToValueListParameter` `IsReadOnly` `IsHidden` `HiddenCondition` `IsPicture` `IsSplitLine` `IsGrid` `IsShowTime` `IsOpenFile` `IsSaveValueToLocal` `IsMustInput` `IsMustBeUpper` `IsValidation` `MustValueMoreThan` `MustValueLessThan` `MustLengthMoreThan` `MustLengthLessThan` `MustIncludedChar` `RegularExpression` `AccessCode` `UIStyleLabel` `UIStyleControl` `DefaultValue` `DefaultChart` |
| `MESTxnObjectMethod` | `MESTxnObjectMethodId` `MESTxnObjectId` `MESTxnObjectMethodName` `MethodSequence` `SQLDoTxn` `TxnParameter` `IsHidden` `RefreshGridParameter` `IsBeforeRunningConfirm` `IsResetWhenDone` `IsAutoRunWhenTabActive` `IsPlaySound` `PromptMessage` `AccessCode` `LabelCopies` `LabelLeftMargin` `LabelTopMargin` `LabelFileSP` `LabelFileName` `IsWriteToPort` `PortNumber` `UIStyle` `IsPreview` `IsShowDataSetWindow` `ButtonPicture` `UDialogParameter` |

### 移动事务

| 表 | 关键列 |
|---|---|
| `MobileObject` | `MobileObjectId` `MobileObjectName` `MobileObjectDesc` `IsActivity` `ColumnCount` `FieldWidth` `FieldSpace` `MsgCount` `AccessCode` |
| `MobileObjectParameter` | `MobileObjectParameterId` `MobileObjectId` `MobileObjectParameterName` `DataType` `ParameterSequence` `IsValueListUsage` `ControlLine` `ValueList` `LinkToValueListParameter` `IsReadOnly` `IsHidden` `HiddenCondition` `IsPicture` `IsSplitLine` `IsGrid` `IsShowTime` `IsSaveValueToLocal` `IsMustInput` `AccessCode` `DecimalPlace` |
| `MobileObjectMethod` | `MobileObjectMethodId` `MobileObjectId` `MobileObjectMethodName` `MethodSequence` `SQLDoTxn` `TxnParameter` `IsHidden` `IsPlaySound` `RefreshGridParameter` `IsBeforeRunningConfirm` `IsAutoRunWhenTabActive` `PromptMessage` `AccessCode` `IsGetGPS` |
| `OrDroid_MobileObject` | `OrDroid_MobileObjectId` `OrDroidPluginId` `MobileObjectId` `MobileObjectSequence` |

### 公共

| 表 | 关键列 |
|---|---|
| `SysParameter` | `ParameterId` `ParameterName` `ParameterValue` `ParameterValueEx` `CreateDate` |
| `SysText` | `TextOwner` `TextModule` `Text2` |
| `SysObject` | `ObjectId` `ObjectName` `ObjectDescription` `ObjectType` `ObjectPKHeader` `ObjectPKCounter` |
| `SysMenu` | `MenuId` `MenuGroupId` `PlugInId` `MenuSequence` |
| `SysMenuGroup` | `MenuGroupId` `MenuGroupName` `UserGroupId` |
| `SysUserGroup` | `UserGroupId` `UserGroupName` `ApplicationId` |
| `SysApplication` | `ApplicationId` `ApplicationName` |

## 关联路径

```text
插件命令
  → SysPlugIn.PluginCommand / OrDroidPlugin.OrDroidPluginCommand

静态事务
  → SysPlugIn.PluginParameter
  → [MESTXN:名称]
  → SysParameter.ParameterName = 整个 PluginParameter
  → SysParameter.ParameterValue
  → MESTxnObject.MESTxnObjectName
  → MESTxnObjectId → Parameter / Method

移动事务（PC 侧）
  → SysPlugIn.PluginParameter
  → [MOBILETXN:名称]
  → SysParameter.ParameterName = 整个 PluginParameter
  → SysParameter.ParameterValue
  → MobileObject.MobileObjectName

移动事务（OrDroid 侧）
  → OrDroidPlugin.OrDroidPluginCommand
  → OrDroidPluginId
  → OrDroid_MobileObject.MobileObjectId
  → MobileObject
  → MobileObjectId → Parameter / Method

查询元
  → SysPlugIn.MetadataId
  → SysMetadata
  → MetadataId
  → SysMetadataFieldGroup
  → MetadataFieldGroupId
  → SysMetadataQuery（条件）
  → SysMetadataMethod（按钮）
```

一个插件在 `SysParameter` 里映射到多个值时，是同一插件的多个页签或页面，不要当成重名。

## 注意

- `PluginCommand`、`MetadataId`、`MESTxnObjectId` 等是定长 `char`，比较时两边都 `RTRIM`。
- 查询元条件字段在 `SysMetadataQuery`，不在 `SysMetadataField`。
- 脚本只做查询，不写库。`sql` 动作只允许单条 `SELECT` / `WITH`。
- 这套脚本和 `server/app.py` 用同一份 catalog 和 secrets；新增环境只要加这两个文件。
