--**==================================================------
--****************************************************------
--**注意：执行脚本后会修改表结构，请确认执行
--****************************************************------
--**==================================================------
--
-- 模板说明（生成时替换）：
--   {TableName}           业务表名，PascalCase
--   {TableDescription}    表的中文说明
--   {CreateColumns}       CREATE TABLE 体内完整列定义（最后一列后无逗号）
--   {AlterBlocks}         表已存在时，按列重复的 IF NOT EXISTS + ALTER TABLE ADD
--   {ColumnDescriptions}  每一列一条 MS_Description，含主键列。见同目录 mtable_alter_block_example.sql
-- 业务表保留第 2 段序列。日志表删掉第 2 段，不建 {TableName}_PK。
--

-----=====================[{TableName}](创建表、修改表)==================================---
IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE [name] = N'{TableName}' AND xtype = N'U')
BEGIN
    CREATE TABLE [dbo].[{TableName}]
    (
{CreateColumns}
    );
END
ELSE
BEGIN
{AlterBlocks}
END
GO

-- 业务表：表新建或补列之后都检查序列。日志表删除本段。
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = N'{TableName}_PK' AND schema_id = SCHEMA_ID(N'dbo'))
BEGIN
    CREATE SEQUENCE [dbo].[{TableName}_PK]
        AS BIGINT
        START WITH 1
        INCREMENT BY 1
        NO CYCLE;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.{TableName}')
      AND minor_id = 0
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'{TableDescription}',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'{TableName}';
END
GO

{ColumnDescriptions}
