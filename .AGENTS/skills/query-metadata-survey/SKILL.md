---
name: query-metadata-survey
description: >-
  拿到一个已有的查询元对象（Plugin Query.dll），说明它查什么、从哪打开、每个元字段组和按钮怎么用、结果里有什么。
  用户给出插件命令、元对象名（MetadataName）或报表/查询界面时使用。
  新建或修改查询元对象、静态事务对象、移动事务对象、标准元对象、看板不要读。
---

# 查询元对象梳理

查询元对象是 PC 客户端上的查询、报表界面。页面按**元字段组**分块：每个字段组是一块查询区或页签，带自己的查询条件和查询按钮，结果直接以表格返回。

少数查询元对象同时带列表、详情和保存，属于「查询 + 维护」页面，按后面的分支处理。

只读。不建表，不改元对象，不改过程。

查库先读 `.AGENTS/skills/mes-db/SKILL.md`，只查当前这一套 MES 库，只用 `query` 和 `procedure`。这套库没有 `procedure` 时，过程和结果列写「这套库看不了过程，说不清怎么用」。

MES 库的这套表结构一致。表或列查不到时，停下告诉用户这是环境问题，不要自己改查别的表。

快速查询优先用 `scripts/query_meta.ps1 -Action query -Key <插件命令或 MetadataName>`，一次返回元对象、元字段组、各组条件和按钮；下面的 SQL 用于核对或工具没覆盖的情况。动作说明见 `mes-meta-query` 技能。

## 做到哪算完

一份 UTF-8 文件：

```text
tasks/{MCP名}/flow/{PluginCommand}/survey.md
```

`{MCP名}` 用 `mes-db` 里的英文名。`PluginFileName` 不是 `Plugin Query.dll` 时不要写这个文件，直接告诉用户这不是查询元对象。

## 先找到元对象

手上要有插件命令、元对象名或表名。都没有就问。`PluginCommand` 是定长，比较时两边都 `RTRIM`。

按插件命令查：

```sql
SELECT RTRIM(a.PluginCommand) AS PluginCommand, a.PluginName,
       RTRIM(a.PluginFileName) AS PluginFileName,
       RTRIM(a.MetadataId) AS MetadataId,
       b.MetadataName, b.MetadataDescription, RTRIM(b.ParentMetadataId) AS ParentMetadataId,
       b.TreeView, b.SubTreeView, b.MainView, b.MainSave, b.MainDelete,
       b.FilterField, b.IsTreeViewStyle, b.IsEnterKeySupport, b.IsMultiPageSupport,
       RTRIM(b.ObjectId) AS ObjectId
FROM dbo.SysPlugIn AS a WITH (NOLOCK)
LEFT JOIN dbo.SysMetadata AS b WITH (NOLOCK) ON b.MetadataId = a.MetadataId
WHERE RTRIM(a.PluginCommand) = @PluginCommand;
```

只有元对象名时改查 `b.MetadataName`。只有表名时，用 `SysObject.ObjectName` 连到 `SysMetadata.ObjectId`，但先看下面这条。

查到多条就列出来问，不自己挑。

### 表名多半查不到

多数查询元对象共用占位对象：`_MyQuery`（查询公用表对象）或 `_Ls`。用表名反查会落回这些占位对象，命中一大片。

先确认：

```sql
SELECT RTRIM(ObjectId) AS ObjectId, ObjectName, ObjectDescription, ObjectType
FROM dbo.SysObject WITH (NOLOCK)
WHERE RTRIM(ObjectName) = @ObjectName;
```

`ObjectName` 是 `_MyQuery`、`_Ls` 这类公用对象时，不要按它继续找，直接问用户要插件命令或元对象名。

中文名取 `SysText.Text2`，`TextOwner = N'[Public Text]'`。字段组名、字段名、方法名都按这个查。

## 先列元字段组

查询条件字段在 `SysMetadataQuery`，不在 `SysMetadataField`。查询元对象一般没有普通字段。

```sql
SELECT RTRIM(g.MetadataFieldGroupId) AS FieldGroupId,
       g.FieldGroupName, g.FieldGroupSequence, g.ColumnCount,
       g.FieldGroupHeight, g.IsCollapsed, g.IsHidden
FROM dbo.SysMetadataFieldGroup AS g WITH (NOLOCK)
WHERE g.MetadataId = @MetadataId
ORDER BY g.FieldGroupSequence, g.MetadataFieldGroupId;
```

一个字段组就是页面上的一块查询区或一个页签。写文件时一组一节，不要把不同组的条件和按钮混在一张表里。

`IsCollapsed` 为真：这一组默认收起；`IsHidden` 为真：这一组不显示。`ColumnCount` 是这一组条件的列数。

## 再看每个字段组

查询条件：

```sql
SELECT RTRIM(q.MetadataQueryId) AS QueryFieldId,
       q.FieldName, q.DataType, q.FieldSequence,
       q.IsValueListUsage, q.ValueList, q.LinkToValueListField,
       q.IsReadOnly, q.IsHidden, q.IsShowTime, q.ControlLine, q.IsOpenFile
FROM dbo.SysMetadataQuery AS q WITH (NOLOCK)
WHERE RTRIM(q.MetadataFieldGroupId) = @FieldGroupId
ORDER BY q.FieldSequence, q.MetadataQueryId;
```

按钮和查询入口：

```sql
SELECT RTRIM(m.MetadataMethodId) AS MethodId,
       m.MethodSequence, m.MethodName, m.SQLDoMethod,
       m.MainViewParameter, m.DialogParameter, m.UDialogParameter,
       m.IsBeforeRunningConfirm, m.PromptMessage,
       m.IsAutoRunQuery, m.IsRefreshTreeView, m.IsAcceptMainViewAsParameter,
       m.IsRunSubQuery, m.SubQuerySQLMethod, m.SubQueryParameter,
       m.QuerySummaryField, m.QueryMargedField, m.IsShowRowIndex,
       m.IsPrintMethod, m.IsPreview, m.LabelFileSP, m.LabelFileName,
       m.IsShowDataSetWindow, m.AccessCode
FROM dbo.SysMetadataMethod AS m WITH (NOLOCK)
WHERE RTRIM(m.MetadataFieldGroupId) = @FieldGroupId
ORDER BY m.MethodSequence, m.MetadataMethodId;
```

怎么读这些列：

- `SQLDoMethod`：这个入口真正调的过程；结果表就是这个查询返回的列。
- `MainViewParameter`：按名称对应本组的查询条件字段，说明这个入口用哪些条件。
- `IsAutoRunQuery`：这个组打开就自动跑，不需要点按钮。
- `IsRunSubQuery`：主查询跑完再自动跑 `SubQuerySQLMethod`，通常是明细/子表，不单独算一个按钮。
- `QuerySummaryField`：结果里的合计列；`QueryMargedField`：同值合并显示的列。
- `IsPrintMethod` 为真：打印入口，不是查询；`IsPreview` 为真：结果先弹预览，不要当成打印。
- `AccessCode` 非空：要权限码。
- 多个入口共用同一个 `SQLDoMethod` 时，过程只读一次，结果列共用；按钮表里每个入口各占一行，注明「同一过程」。

数据类型按这个读：

| `DataType` | 界面 |
|---|---|
| `C` | 文本 |
| `D` | 日期；`IsShowTime` 为真时带时间 |
| `B` | 勾选 |
| `I` | 整数 |

## 分支：纯查询，还是查询 + 维护

看 `TreeView`、`MainView`、`MainSave`、`MainDelete`：

- 都为空：纯查询页。按元字段组写条件、按钮、结果列。
- 有非空：查询 + 维护页。查询条件仍是 `SysMetadataQuery`；点开一条之后的详情、保存、删除看 `MainView`、`MainSave`、`MainDelete`。用 `procedure` 读这些过程，按标准元的读法写：列表能看见什么、详情填什么、保存检查什么、删除会怎样。
- `SubTreeView` 非空：树还有下级列表，一并读。
- `FilterField` 非空：树按这个字段过滤。
- `IsTreeViewStyle` 为真：打开后先有左侧列表，再查询。
- `IsEnterKeySupport` 为真：条件里按回车就执行查询。
- `IsMultiPageSupport` 为真：结果分多页。

有子页面时（`ParentMetadataId` 等于本元对象）各加一节，说明从哪进、看什么。

## 读过程

对每个 `SQLDoMethod`、`SubQuerySQLMethod` 和非空的 `MainView`/`MainSave`/`MainDelete` 用 `procedure` 读。只抓这几样：

- 过程要求哪些参数，缺了会怎样（必填校验、默认值）。
- 从哪些表取数，关联了谁；过滤条件是什么。
- 返回哪些列，列的含义；列的中文名能对上 `SysText` 就写中文。
- 有没有特殊限制，例如只允许在报表服务器执行、按工厂/权限过滤、写查询日志。
- 有没有写操作。纯查询不应该写业务表；发现 `INSERT`/`UPDATE`/`DELETE` 要单独写出来。

过程很长时只读参数段、`FROM`/`JOIN`、`WHERE` 和最后的 `SELECT`，不要整段贴进文件。

## 写成使用说明

按元字段组一节一节写：

```markdown
# {中文名}

库：{MCP名}。插件 {PluginCommand}（{PluginName}）。查询元对象 {MetadataName}。

用来干什么：{查什么业务数据，一两句}

怎么打开：{MES 客户端里的插件中文名}

## 页面怎么用

1. 打开后先看到哪几个字段组，页签顺序是什么。
2. 每组先填哪些条件。
3. 点哪个入口，回车还是按钮。
4. 结果怎么读，哪些列是合计/合并显示。
5. 有哪些权限或服务器限制。

## 字段组：{FieldGroupName}

{这一组在页面上是什么，什么时候用}

### 查询条件

| 界面上叫 | 字段名 | 类型 | 必填 | 取值 |
|---|---|---|---|---|

### 按钮

| 界面上叫 | 要填什么条件 | 返回什么 | 点下去做什么 |
|---|---|---|---|

### 结果里有什么

{这一组各入口返回的列和口径；列多时按业务分组，不要逐个列名堆成一段}

{下一组重复「字段组」一节}

## 查询 + 维护页

{只有带 TreeView/MainView/MainSave/MainDelete 时才有这一节：
列表、详情、保存、删除、子页面怎么用}

## 说不清的
```

- 一个字段组一节；不同组的条件和按钮不混表。
- 组内按钮多时按业务再分组；共用同一过程的入口合并说明，但入口名都要列出来。
- 自动执行的子查询写进对应入口的「返回什么」，不单独占一行。
- 打印入口写清打印什么标签或报表，不写业务查询逻辑。
- 纯查询页删掉「查询 + 维护页」这一节。
- 看不懂的放最后，不猜。
