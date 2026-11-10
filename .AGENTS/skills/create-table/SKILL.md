---
name: create-table
description: >-
  创建 SQL Server 2016 业务表，生成标准 {表名}_MTable.sql。
  Agent 一旦产出或修改 `{表名}_MTable.sql`、或过程 INSERT 新物理表，必须完整 Read 本技能并执行 Step 1～7；
  日志表跳过 Step 6。
  仅改已有表对应的过程/元数据、且不碰 MTable 时不要读。
version: "2.1.3"
agent_created: true
---

# 表创建技能（SQL Server 2016）- 精简版

> **调用契约（Agent）**：凡交付 `{表名}_MTable.sql`（新建或改列），**必须先完整 Read 本文件**，再按 Step 1～7 写 DDL。日志表跳过 Step 6。Step 2 分不清是新建还是补列、以及 Step 4 列设计完成时，必须停下来等用户决定，不能自己继续。禁止未走完这些步骤就手写 MTable（含「只改 API 过程里 INSERT 新表」的场景——仍须先本技能建表脚本）。  
> **不要读**：表与合规 MTable 已存在，只改存储过程/元数据、且不新增物理表。写 DDL 前按 **表类型** 选型。

## 先选分支

只有两种表。差别在主键怎么产生，其余列规则相同。

| 分支 | 适用 | 主键列 | 主键从哪来 |
|------|------|--------|------------|
| **业务表** | 界面维护、标准元增删改 | `{表名}Id` `CHAR(12) NOT NULL`，无默认值 | 系统函数生成。`Fn_GetObjectPKId` 或 `SysGetObjectPKId` 取 `SysObject` 前缀，再读序列 `{表名}_PK`，拼成 12 位。序列从 1 起 |
| **日志** | 只追加、审计、按钮写历史 | `{表名}Id` `BIGINT IDENTITY(1,1) NOT NULL` | 系统自增。不建序列 |

两种都建主键约束 `PK_{表名}`。业务表不给主键写 `DEFAULT`。日志表不给主键赋值。

业务表的完成标准是 `SysObjectSaveData` 返回 0，`SysObject` 里有这张表，测试插入的主键和数据都正常，并且回滚后这一行已经不在表里。日志表不调用这个过程，也不插这条。

日志可以只有 `CreateDate`。业务表要有 `CreateDate`、`ModifyDate`、`IsCancel`。

日志示例：`MOQtyExtendAllowLog`（延号允许数量变更历史）。

---

## 写进 DDL 的约束

选定分支后再写。这些约束写在脚本里，不单独先交一份空清单。

- 字符串：`NOT NULL DEFAULT ''`
- 整数：`NOT NULL DEFAULT 0`。日志主键是 `IDENTITY`，不设默认值
- `BIT`：`NOT NULL DEFAULT 0`，或业务要求的 `DEFAULT 1`
- 日期：`NOT NULL DEFAULT GETDATE()`
- 业务表主键：`CHAR(12) NOT NULL`，无默认值。建表脚本里不写取号函数，也不手写 12 位号码。函数留到 Step 6 插入测试数据时用
- 表和每一列都写 `MS_Description`
- 示例数据不放进要执行的 `{表名}_MTable.sql`

---

## 执行步骤

### Step 1：确认环境与范围

- 查库先读 `.AGENTS/skills/mes-db/SKILL.md`，只对当前这一套库执行下面的检索。测试环境可以直接执行。正式环境的建表、登记和测试插入先写成 `.sql`，用户授权这一次才执行，否则由用户自己执行
- 目标库：**SQL Server 2016**，持久业务表
- 记录：表中文用途、**英文表名（PascalCase）**、逻辑关联表（仅记录关联关系，不创建数据库外键）

> **命名规则（强制）**
> - **表名**：必须使用英文，PascalCase（如 `Product`、`WorkOrder`）
> - **字段名**：必须使用英文，PascalCase（如 `ProductCode`、`LotQty`）
> - **中文说明**：放在 MS_Description 注释中

### Step 2：表名检索（强制）

```sql
-- 检查表是否存在
DECLARE @TableName NVARCHAR(128) = N'表名';
IF OBJECT_ID(N'dbo.' + @TableName, N'U') IS NOT NULL
BEGIN
    SELECT t.name AS TableName, N'表已存在' AS Status
    FROM sys.tables AS t WHERE t.name = @TableName;
    PRINT '表 ' + @TableName + ' 已存在';
END
ELSE
BEGIN
    SELECT @TableName AS TableName, '表不存在，可以新建' AS Status;
    PRINT '表 ' + @TableName + ' 不存在';
END
```

表不存在：按新建继续。

表已存在时先看用户有没有说清意图：

- 已经说清是给这张表加列：不换名，Step 5 走补列分支。
- 已经说清是另建一张新表：换一个表名，回到本步再查一次。
- 分不清是新建还是给旧表加列：停下来。把已有表名告诉用户，请用户选定其中一种。选定之前不进入 Step 3。

### Step 3：库内检索（强制）

按优先级检索字段：
1. **同名列** → 2. **MS_Description 注释匹配** → 3. **systext 表**

```sql
-- 通用检索模板（替换 @Target 为字段名或关键词）
DECLARE @Target NVARCHAR(100) = N'目标';

-- 优先级1：同名列
SELECT c.COLUMN_NAME, c.DATA_TYPE, c.CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS c WHERE c.COLUMN_NAME = @Target;

-- 优先级2：注释匹配（取使用次数最多的字段名）
SELECT TOP 1 c.name AS ColumnName, COUNT(*) AS UsageCount
FROM sys.columns c
INNER JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
WHERE ep.name = N'MS_Description' AND ep.value LIKE N'%' + @Target + N'%'
GROUP BY c.name ORDER BY UsageCount DESC;


-- 优先级 3：systext 表检索（Text1 英文，Text2 中文）
-- 如果匹配到多个字段名，取出现次数最多的字段名
SELECT TOP 1 c.name AS ColumnName, COUNT(*) AS UsageCount
FROM sys.columns c INNER JOIN systext tx ON tx.id = c.object_id AND tx.colid = c.column_id
WHERE tx.Text1 LIKE N'%' + @Target + N'%' OR tx.Text2 LIKE N'%' + @Target + N'%'
GROUP BY c.name ORDER BY UsageCount DESC;
```

**结论**：记录哪些列名沿用库内习惯、哪些新建。

### Step 4：设计表结构

按下面的规范设计：

| 规则项 | 具体要求 |
|--------|---------|
| **表名** | 英文 PascalCase，≤30字符，禁止保留字和`sys`前缀 |
| **字段名** | 英文 PascalCase，≤30字符 |
| **主键** | 业务表：`{表名}Id CHAR(12)`，值由系统函数生成。日志：`{表名}Id BIGINT IDENTITY(1,1)`，不建序列、不调函数 |
| **主键约束** | 两种都是 `PK_{表名}`（如 `PK_Product`） |
| **审计字段** | 业务表：`CreateDate`、`ModifyDate`、`IsCancel`。日志：至少 `CreateDate` |
| **字符串默认值** | NOT NULL DEFAULT '' |
| **数字默认值** | NOT NULL DEFAULT 0 |
| **数量字段** | 以`Qty`结尾（如`LotQty`、`RealQty`） |
| **布尔字段** | `Is{含义}`/`Has{含义}` + BIT NOT NULL DEFAULT 0 |
| **外键字段** | `{关联表名}Id` + CHAR(12) NOT NULL DEFAULT ''，仅作为业务关联字段，不创建数据库外键约束 |
| **字段注释** | 每字段必须有 MS_Description 中文说明 |
| **字符串类型** | 中文用 NVARCHAR，英文用 VARCHAR，按需分配长度 |
| **金额字段** | DECIMAL(18,2) 或 DECIMAL(18,4) |

**禁用类型**：
- ❌ TEXT、NTEXT、IMAGE
- ❌ FLOAT、REAL（金额字段）

列清单写完后停下来，交给用户看。用户说继续，才进入 Step 5。用户要求再改列，改完再停一次，仍等用户确认。未确认之前不写 `{表名}_MTable.sql`。

### Step 5：生成 MTable 脚本（强制）

交付文件是 `{表名}_MTable.sql`，编码 UTF-8。目录名用英文，第一段用当前这套库的 MCP 名：

```text
{MCP名}/dev/{功能英文名}/{表名}_MTable.sql
```

`{MCP名}` 是 `jiban-mes-test`、`jiban-mes-prod`、`zongzhuang-mes-test`、`zongzhuang-mes-prod`、`tongxin-mes-prod`、`guangyuan-mes-prod`、`guangyuan-wms-prod` 之一。`{功能英文名}` 没有另给时用表名。例如 `jiban-mes-test/dev/Product/Product_MTable.sql`。先按分支写下主键列，再按本技能 `assets` 里的两份模板拼完整脚本。不要打开其他技能或规则。

主键列：

业务表：

```sql
[{表名}Id] CHAR(12) NOT NULL CONSTRAINT [PK_{表名}] PRIMARY KEY,
```

日志：

```sql
[{表名}Id] BIGINT NOT NULL IDENTITY(1, 1) CONSTRAINT [PK_{表名}] PRIMARY KEY,
```

业务表这一列不写默认值，也不写 `Fn_GetObjectPKId`。取号放在 Step 6，登记成功后插入测试数据时用。日志插入不写主键列。

关联其他表只留 `{关联表名}Id CHAR(12)`，不建外键。索引只为查询、过滤、排序建，不为关联另建。

参考模板：本技能 `assets/mtable_script_template.sql` 和 `assets/mtable_alter_block_example.sql`

**结构**以 `assets/mtable_script_template.sql` 为准，按这个顺序：
1. 警示头注释
2. 表不存在则 `CREATE TABLE`，已存在则按列 `ALTER TABLE ADD`。已有列不重建主键
3. 业务表接着检查序列 `{表名}_PK`。这段在建表分支外面，补列时也会补上。日志表删掉这一段
4. 表注释和每一列的 `MS_Description`，缺一列都不能交给 `SysObjectSaveData`
5. 业务表的登记不写在模板里，转到 Step 6。日志表到本步结束

序列只属于业务表，给系统函数取号：`START WITH 1`，`INCREMENT BY 1`。主键字符串由函数生成，不是序列当前值本身。

### Step 6：业务表登记元对象

表、主键索引 `PK_{表名}`、每列注释都已写上之后，才调用。过程会先检查这三样，缺一件就返回 -1。

`@I_PKId` 用 `SysGetObjectPKId` 为 `SysObject` 取一个新号。`@ObjectName` 等于表名。`@ObjectPKHeader` 先查重，查过再写进调用。

```sql
SELECT ObjectName, ObjectPKHeader
FROM dbo.SysObject
WHERE ObjectName = N'{表名}';
```

这里有一行，说明本表已经登记。沿用这一行的 `ObjectPKHeader`，不再调用 `SysObjectSaveData`，也不再插入测试数据。补列同样不重新取前缀。没有这一行，再查候选前缀：

```sql
DECLARE @Header CHAR(4) = N'{四位前缀}';

SELECT ObjectName, ObjectPKHeader
FROM dbo.SysObject
WHERE ObjectPKHeader = @Header;
```

查出任何一行，这个前缀已被占用，换一个 4 位值再查。结果为空，才把 `@Header` 交给下面的 `@ObjectPKHeader`。

```sql
DECLARE @ObjectId CHAR(12) = '';
DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
DECLARE @IsNewRow BIT = 0;
DECLARE @ExceptionFieldName NVARCHAR(100) = N'';

EXEC dbo.SysGetObjectPKId
    @ObjectName = N'SysObject',
    @PKID = @ObjectId OUTPUT;

EXEC dbo.SysObjectSaveData
    @I_ReturnMessage = @ReturnMessage OUTPUT,
    @I_IsNewRow = @IsNewRow OUTPUT,
    @I_ExceptionFieldName = @ExceptionFieldName OUTPUT,
    @I_PKId = @ObjectId,
    @ObjectName = N'{表名}',
    @ObjectDescription = N'{表中文说明}',
    @ObjectType = N'O',
    @ObjectRev = N'10.00',
    @ObjectPKHeader = '{四位前缀}',
    @ObjectPKCounter = 0;
```

完成要同时满足：

- 过程返回 0
- `@ReturnMessage` 不是 `NamingConflicts` 或 `PkHeaderConflicts`，也不是缺主键、缺注释的 `ServerMessage`
- `SELECT ObjectId, ObjectName, ObjectPKHeader FROM dbo.SysObject WHERE ObjectName = N'{表名}'` 有一行

日志表的主键不是 `char(12)`，这个过程会直接失败，所以不登记，也不做下面的测试插入。

`SysObjectSaveData` 返回 0 并已提交之后，单独开一个事务插入一条测试数据。这条不写进 `{表名}_MTable.sql`。登记本身不要放进这个事务，否则回滚会把元对象一起撤掉。

```sql
BEGIN TRAN;

DECLARE @Id CHAR(12) = dbo.Fn_GetObjectPKId(12, N'{表名}', NEXT VALUE FOR dbo.{表名}_PK);

INSERT INTO dbo.{表名} ([{表名}Id])
VALUES (@Id);

SELECT *
FROM dbo.{表名}
WHERE [{表名}Id] = @Id;
```

先看这一行，两项都正常才算通过：

- 主键：长度 12。前 4 位等于刚登记的 `ObjectPKHeader`。后 8 位只含 `0-9`、`A-Z`。
- 数据：除主键外，每一列都等于建表时写的默认值。`CreateDate`、`ModifyDate` 有值，`IsCancel = 0`。

不正常也要回滚，并且不算通过。正常则回滚，再确认测试行已经不在表里：

```sql
ROLLBACK TRAN;

SELECT [{表名}Id]
FROM dbo.{表名}
WHERE [{表名}Id] = @Id;
```

上面查不到行，业务表才算通过。回滚只撤掉这一行。序列 `{表名}_PK` 已经取过的号不会退回。

### Step 7：自检

交付 `{表名}_MTable.sql`，编码 UTF-8，放在 Step 5 的目录。内容是表结构、序列或自增、字段注释。业务表在 Step 6 成功后，把 `SysObjectSaveData` 也放进这份脚本。测试插入不放进这份脚本。

| 检查项 | 业务表 | 日志 |
|--------|--------|------|
| 表名、字段英文 PascalCase | 要 | 要 |
| 库内字段检索有结论 | 要 | 要 |
| 主键 | 系统函数生成的 `CHAR(12)`，序列 `{表名}_PK` 从 1 起 | `BIGINT IDENTITY(1,1)`，无序列、无函数 |
| 约束名 `PK_{表名}` | 要 | 要 |
| 审计字段 | `CreateDate`、`ModifyDate`、`IsCancel` | 至少 `CreateDate` |
| 默认值、每列中文 `MS_Description` | 要 | 要 |
| 测试插入不在 MTable 里 | 要 | 要 |
| 登记元对象 | 前缀查重为空才保存。`SysObjectSaveData` 返回 0。测试行的主键和默认值都正常，回滚后查不到该行 | 不调用、不插入 |

---

## 完整示例

### 示例1：业务表

```sql
[ProductId] CHAR(12) NOT NULL CONSTRAINT [PK_Product] PRIMARY KEY,
[ProductCode] VARCHAR(30) NOT NULL DEFAULT '',
[ProductName] NVARCHAR(100) NOT NULL DEFAULT '',
[CreateDate] DATETIME NOT NULL DEFAULT GETDATE(),
[ModifyDate] DATETIME NOT NULL DEFAULT GETDATE(),
[IsCancel] BIT NOT NULL DEFAULT 0
```

序列名 `Product_PK`，从 1 起。登记成功后用 `Fn_GetObjectPKId` 插入一条测试数据，核对主键和默认值，正常后回滚。查询列再加普通索引，例如 `IX_Product_ProductCode`。

### 示例2：日志

```sql
[MOQtyExtendAllowLogId] BIGINT NOT NULL IDENTITY(1, 1) CONSTRAINT [PK_MOQtyExtendAllowLog] PRIMARY KEY,
[MOId] CHAR(12) NOT NULL DEFAULT '',
[CreateDate] DATETIME NOT NULL DEFAULT GETDATE()
```

不建 `MOQtyExtendAllowLog_PK`。`MOId` 只表示关联，不建外键。
