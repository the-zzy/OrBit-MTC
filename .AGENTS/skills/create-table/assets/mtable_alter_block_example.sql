-- 单字段 ALTER 块（放进模板的 {AlterBlocks}，按列重复）
    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.{TableName}', N'U') AND name = N'{ColumnName}'
    )
    BEGIN
        ALTER TABLE [dbo].[{TableName}] ADD [{ColumnName}] {ColumnTypeAndNullDefault};
    END

-- 单列注释（放进模板的 {ColumnDescriptions}，主键列和业务列都要有）
IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.{TableName}')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.{TableName}'), N'{ColumnName}', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'{ColumnDescription}',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'{TableName}',
        @level2type = N'COLUMN', @level2name = N'{ColumnName}';
END
GO
