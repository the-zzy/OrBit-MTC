--**==================================================------
--****************************************************------
--**注意：执行脚本后会修改表结构，请确认执行
--****************************************************------
--**==================================================------
--
-- 基板正式。国外 CKD 订单（KDYN）手工完成标记。
-- 一行对应一张散件订单。IsManualFinish = 1 表示手工标成已完成。
-- 列表上的数量在 TreeView 里按这批订单现算，不读本表的数量。
--

-----=====================[KDOrderFinishMark](创建表、修改表)==================================---
IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE [name] = N'KDOrderFinishMark' AND xtype = N'U')
BEGIN
    CREATE TABLE [dbo].[KDOrderFinishMark]
    (
        [KDOrderFinishMarkId] CHAR(12) NOT NULL CONSTRAINT [PK_KDOrderFinishMark] PRIMARY KEY,
        [KDOrderInfoId] CHAR(12) NOT NULL DEFAULT '',
        [IsManualFinish] BIT NOT NULL DEFAULT 0,
        [CreateUserId] CHAR(12) NOT NULL DEFAULT '',
        [CreateUserName] NVARCHAR(100) NOT NULL DEFAULT '',
        [CreateDate] DATETIME NOT NULL DEFAULT GETDATE(),
        [ModifyDate] DATETIME NOT NULL DEFAULT GETDATE(),
        [IsCancel] BIT NOT NULL DEFAULT 0
    );
END
ELSE
BEGIN
    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'KDOrderInfoId'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [KDOrderInfoId] CHAR(12) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'IsManualFinish'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [IsManualFinish] BIT NOT NULL DEFAULT 0;
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'CreateUserId'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [CreateUserId] CHAR(12) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'CreateUserName'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [CreateUserName] NVARCHAR(100) NOT NULL DEFAULT '';
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'CreateDate'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [CreateDate] DATETIME NOT NULL DEFAULT GETDATE();
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'ModifyDate'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [ModifyDate] DATETIME NOT NULL DEFAULT GETDATE();
    END

    IF NOT EXISTS (
        SELECT * FROM dbo.syscolumns
        WHERE id = OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') AND name = N'IsCancel'
    )
    BEGIN
        ALTER TABLE [dbo].[KDOrderFinishMark] ADD [IsCancel] BIT NOT NULL DEFAULT 0;
    END
END
GO

-- 业务表：表新建或补列之后都检查序列。日志表删除本段。
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = N'KDOrderFinishMark_PK' AND schema_id = SCHEMA_ID(N'dbo'))
BEGIN
    CREATE SEQUENCE [dbo].[KDOrderFinishMark_PK]
        AS BIGINT
        START WITH 1
        INCREMENT BY 1
        NO CYCLE;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_KDOrderFinishMark_KDOrderInfoId'
      AND object_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
)
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [IX_KDOrderFinishMark_KDOrderInfoId]
        ON [dbo].[KDOrderFinishMark] ([KDOrderInfoId])
        WHERE [IsCancel] = 0;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = 0
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'散件订单手工完成标记',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'KDOrderFinishMarkId', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'主键',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'KDOrderFinishMarkId';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'KDOrderInfoId', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'散件订单',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'KDOrderInfoId';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'IsManualFinish', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'手工标成已完成',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'IsManualFinish';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'CreateUserId', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'创建人',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'CreateUserId';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'CreateUserName', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'创建人姓名',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'CreateUserName';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'CreateDate', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'创建时间',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'CreateDate';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'ModifyDate', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'修改时间',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'ModifyDate';
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderFinishMark')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderFinishMark'), N'IsCancel', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'作废',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderFinishMark',
        @level2type = N'COLUMN', @level2name = N'IsCancel';
END
GO

IF EXISTS (
    SELECT 1
    FROM dbo.SysObject
    WHERE ObjectPKHeader = N'KDFN'
      AND ObjectName <> N'KDOrderFinishMark'
)
BEGIN
    THROW 50001, N'主键前缀 KDFN 已被占用', 1;
END

IF NOT EXISTS (SELECT 1 FROM dbo.SysObject WHERE ObjectName = N'KDOrderFinishMark')
BEGIN
    DECLARE @ObjectId CHAR(12) = '';
    DECLARE @ReturnMessage NVARCHAR(MAX) = N'';
    DECLARE @IsNewRow BIT = 0;
    DECLARE @ExceptionFieldName NVARCHAR(100) = N'';

    EXEC dbo.SysGetObjectPKId
        @ObjectId = '',
        @ObjectName = N'SysObject',
        @PKID = @ObjectId OUTPUT;

    EXEC dbo.SysObjectSaveData
        @I_ReturnMessage = @ReturnMessage OUTPUT,
        @I_IsNewRow = @IsNewRow OUTPUT,
        @I_ExceptionFieldName = @ExceptionFieldName OUTPUT,
        @I_PKId = @ObjectId,
        @ObjectName = N'KDOrderFinishMark',
        @ObjectDescription = N'散件订单手工完成标记',
        @ObjectType = N'O',
        @ObjectRev = N'10.00',
        @ObjectPKHeader = 'KDFN',
        @ObjectPKCounter = 0;

    IF ISNULL(@ReturnMessage, N'') <> N''
    BEGIN
        THROW 50001, @ReturnMessage, 1;
    END
END
GO
