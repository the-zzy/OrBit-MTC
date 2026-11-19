--**==================================================------
--****************************************************------
--**注意：执行脚本后会修改表结构，请确认执行
--****************************************************------
--**==================================================------
--
-- 基板正式。国外 CKD 订单已装柜明细，从总装按装柜时间同步过来。
-- 一行对应总装一条 KDBoxItem。按 KDOrderInfoId 汇总 RealQty 就是该订单的已装柜数量。
-- 同步表，主键自增。不登记元对象，不建序列。
--

-----=====================[KDOrderLoadedItem](创建表、修改表)==================================---
IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE [name] = N'KDOrderLoadedItem' AND xtype = N'U')
BEGIN
    CREATE TABLE [dbo].[KDOrderLoadedItem]
    (
        [KDOrderLoadedItemId] BIGINT NOT NULL IDENTITY(1, 1) CONSTRAINT [PK_KDOrderLoadedItem] PRIMARY KEY,
        [KDBoxItemId] CHAR(12) NOT NULL DEFAULT '',
        [KDOrderInfoId] CHAR(12) NOT NULL DEFAULT '',
        [OrderName] NVARCHAR(100) NOT NULL DEFAULT '',
        [RealQty] DECIMAL(18, 4) NOT NULL DEFAULT 0,
        [Container] VARCHAR(30) NOT NULL DEFAULT '',
        [IssuerDate] DATETIME NOT NULL DEFAULT '1900-01-01',
        [CreateDate] DATETIME NOT NULL DEFAULT GETDATE(),
        [ModifyDate] DATETIME NOT NULL DEFAULT GETDATE()
    );
END
ELSE
BEGIN
    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'KDBoxItemId'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [KDBoxItemId] CHAR(12) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'KDOrderInfoId'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [KDOrderInfoId] CHAR(12) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'OrderName'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [OrderName] NVARCHAR(100) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'RealQty'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [RealQty] DECIMAL(18, 4) NOT NULL DEFAULT 0;
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'Container'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [Container] VARCHAR(30) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'IssuerDate'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [IssuerDate] DATETIME NOT NULL DEFAULT '1900-01-01';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'CreateDate'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [CreateDate] DATETIME NOT NULL DEFAULT GETDATE();
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderLoadedItem', N'U') AND name = N'ModifyDate'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderLoadedItem] ADD [ModifyDate] DATETIME NOT NULL DEFAULT GETDATE();
    END
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'UX_KDOrderLoadedItem_KDBoxItemId'
      AND object_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [UX_KDOrderLoadedItem_KDBoxItemId]
        ON [dbo].[KDOrderLoadedItem] ([KDBoxItemId]);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_KDOrderLoadedItem_KDOrderInfoId'
      AND object_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_KDOrderLoadedItem_KDOrderInfoId]
        ON [dbo].[KDOrderLoadedItem] ([KDOrderInfoId])
        INCLUDE ([RealQty]);
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = 0
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'散件订单已装柜明细',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'KDOrderLoadedItemId', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'主键',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'KDOrderLoadedItemId';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'KDBoxItemId', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'总装装箱明细',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'KDBoxItemId';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'KDOrderInfoId', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'散件订单',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'KDOrderInfoId';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'OrderName', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'订单号',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'OrderName';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'RealQty', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'已装柜数量',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'RealQty';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'Container', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'货柜号',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'Container';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'IssuerDate', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'装柜时间',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'IssuerDate';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'CreateDate', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'创建时间',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'CreateDate';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderLoadedItem')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderLoadedItem'), N'ModifyDate', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'修改时间',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderLoadedItem',
        @level2type = N'COLUMN', @level2name = N'ModifyDate';
END
GO
