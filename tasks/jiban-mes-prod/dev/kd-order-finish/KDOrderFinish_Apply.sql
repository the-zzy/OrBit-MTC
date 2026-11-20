-- 基板正式。已装柜明细已经进表之后执行这一份。
-- 顺序：手工标记表、增量拉取过程、变更按钮过程、按钮元数据、散件订单 TreeView。

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
-- 基板正式。从总装拉取已装柜装箱明细，写入 KDOrderLoadedItem。
-- 订单还没有本地明细时全量拉取。已有明细的订单只拉 IssuerDate 不早于上次最大装柜时间的行。
-- 同一条总装装箱明细再次扫柜时按 KDBoxItemId 更新，不另插一行。
-- 依赖 KDOrderLoadedItem 已建表。链接服务器 [172.16.8.31]。

IF OBJECT_ID(N'dbo.KDOrderLoadedPull', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderLoadedPull;
GO

CREATE PROCEDURE [dbo].[KDOrderLoadedPull]
    @KDOrderInfoId CHAR(12) = ''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewNames NVARCHAR(MAX) = N'';
    DECLARE @OldNames NVARCHAR(MAX) = N'';
    DECLARE @Mark DATETIME;
    DECLARE @Where NVARCHAR(MAX) = N'';
    DECLARE @Remote NVARCHAR(MAX) = N'';
    DECLARE @Sql NVARCHAR(MAX) = N'';

    IF OBJECT_ID(N'tempdb..#LoadedPullOrder') IS NOT NULL DROP TABLE #LoadedPullOrder;
    IF OBJECT_ID(N'tempdb..#LoadedStage') IS NOT NULL DROP TABLE #LoadedStage;

    CREATE TABLE #LoadedPullOrder
    (
        KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
        OrderName NVARCHAR(100) NOT NULL,
        IsNew BIT NOT NULL
    );

    CREATE TABLE #LoadedStage
    (
        OrderName NVARCHAR(100) NOT NULL,
        KDBoxItemId CHAR(12) NOT NULL,
        RealQty DECIMAL(18, 4) NOT NULL,
        Container VARCHAR(30) NOT NULL,
        IssuerDate DATETIME NOT NULL
    );

    INSERT INTO #LoadedPullOrder (KDOrderInfoId, OrderName, IsNew)
    SELECT o.KDOrderInfoId,
           o.OrderName,
           CASE
               WHEN EXISTS (
                   SELECT 1
                   FROM dbo.KDOrderLoadedItem AS t
                   WHERE t.KDOrderInfoId = o.KDOrderInfoId
               ) THEN 0
               ELSE 1
           END
    FROM dbo.KDOrderInfo AS o
    WHERE o.OrderType IN ('8', '9', '10')
      AND ISNULL(o.OrderName, N'') <> N''
      AND (@KDOrderInfoId = '' OR o.KDOrderInfoId = @KDOrderInfoId);

    SELECT @Mark = MAX(t.IssuerDate)
    FROM dbo.KDOrderLoadedItem AS t
    INNER JOIN #LoadedPullOrder AS p ON p.KDOrderInfoId = t.KDOrderInfoId
    WHERE p.IsNew = 0
      AND t.IssuerDate > '1900-01-01';

    SELECT @NewNames = STUFF((
        SELECT N',N''' + REPLACE(OrderName, '''', '''''') + N''''
        FROM #LoadedPullOrder
        WHERE IsNew = 1
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 1, N'');

    SELECT @OldNames = STUFF((
        SELECT N',N''' + REPLACE(OrderName, '''', '''''') + N''''
        FROM #LoadedPullOrder
        WHERE IsNew = 0
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 1, N'');

    IF ISNULL(@NewNames, N'') <> N'' AND ISNULL(@OldNames, N'') <> N'' AND @Mark IS NOT NULL
        SET @Where = N'(z.OrderName IN (' + @NewNames + N') OR (z.OrderName IN (' + @OldNames
            + N') AND box.IssuerDate >= ''' + CONVERT(VARCHAR(19), @Mark, 120) + N'''))';
    ELSE IF ISNULL(@NewNames, N'') <> N''
        SET @Where = N'z.OrderName IN (' + @NewNames + N')';
    ELSE IF ISNULL(@OldNames, N'') <> N'' AND @Mark IS NOT NULL
        SET @Where = N'z.OrderName IN (' + @OldNames + N') AND box.IssuerDate >= '''
            + CONVERT(VARCHAR(19), @Mark, 120) + N'''';
    ELSE IF ISNULL(@OldNames, N'') <> N''
        SET @Where = N'z.OrderName IN (' + @OldNames + N')';
    ELSE
        RETURN 0;

    SET @Remote = N'
SELECT z.OrderName,
       item.KDBoxItemId,
       CONVERT(varchar(40), item.RealQty) AS RealQty,
       ISNULL(box.Container, '''') AS Container,
       ISNULL(CONVERT(varchar(19), box.IssuerDate, 120), '''') AS IssuerDate
FROM OrBitXIZC.dbo.KDOrderInfo AS z WITH (NOLOCK)
INNER JOIN OrBitXIZC.dbo.KDBoxInfo AS box WITH (NOLOCK)
    ON box.KDOrderInfoId = z.KDOrderInfoId
   AND box.IsCancel = 0
   AND ISNULL(box.Container, '''') <> ''''
INNER JOIN OrBitXIZC.dbo.KDBoxItem AS item WITH (NOLOCK)
    ON item.KDBoxInfoId = box.KDBoxInfoId
   AND item.IsCancel = 0
WHERE ' + @Where;

    SET @Sql = N'INSERT INTO #LoadedStage (OrderName, KDBoxItemId, RealQty, Container, IssuerDate)
SELECT OrderName,
       KDBoxItemId,
       CONVERT(decimal(18, 4), RealQty),
       Container,
       CASE WHEN IssuerDate = '''' THEN CONVERT(datetime, ''19000101'') ELSE CONVERT(datetime, IssuerDate) END
FROM OPENQUERY([172.16.8.31], ''' + REPLACE(@Remote, '''', '''''') + N''')';
    EXEC (@Sql);

    MERGE dbo.KDOrderLoadedItem AS t
    USING (
        SELECT s.KDBoxItemId,
               MIN(p.KDOrderInfoId) AS KDOrderInfoId,
               MIN(s.OrderName) AS OrderName,
               MAX(s.RealQty) AS RealQty,
               MAX(s.Container) AS Container,
               MAX(s.IssuerDate) AS IssuerDate
        FROM #LoadedStage AS s
        INNER JOIN #LoadedPullOrder AS p ON p.OrderName = s.OrderName
        GROUP BY s.KDBoxItemId
    ) AS s
        ON t.KDBoxItemId = s.KDBoxItemId
    WHEN MATCHED THEN
        UPDATE SET
            t.KDOrderInfoId = s.KDOrderInfoId,
            t.OrderName = s.OrderName,
            t.RealQty = s.RealQty,
            t.Container = s.Container,
            t.IssuerDate = s.IssuerDate,
            t.ModifyDate = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (KDBoxItemId, KDOrderInfoId, OrderName, RealQty, Container, IssuerDate, CreateDate, ModifyDate)
        VALUES (s.KDBoxItemId, s.KDOrderInfoId, s.OrderName, s.RealQty, s.Container, s.IssuerDate, GETDATE(), GETDATE());

    RETURN 0;
END
GO
-- 基板正式。KDYN 散件订单「变更完成状态」。
-- 未完成可以改为已完成；手工已完成可以改回未完成。
-- 已包装数与本地已装柜明细合计一致时，不允许改回未完成。
-- 已装柜数量先按本单执行 KDOrderLoadedPull，再汇总 KDOrderLoadedItem.RealQty。
-- 依赖 KDOrderFinishMark、KDOrderLoadedItem 已建好。

IF OBJECT_ID(N'dbo.KDOrderFinishChangeDoMethod', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderFinishChangeDoMethod;
GO

CREATE PROCEDURE [dbo].[KDOrderFinishChangeDoMethod]
    @I_Sender NVARCHAR(200) = '',
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId CHAR(1) = '1',
    @I_PlugInCommand VARCHAR(5) = '',
    @I_OrBitUserId CHAR(12) = '',
    @I_OrBitUserName NVARCHAR(100) = '',
    @I_ResourceId CHAR(12) = '',
    @I_ResourceName NVARCHAR(100) = '',
    @I_PKId CHAR(12) = '',
    @I_ParentPKId CHAR(12) = '',
    @I_Parameter NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OrderName NVARCHAR(100) = N'';
    DECLARE @PackQty DECIMAL(18, 4) = 0;
    DECLARE @LoadedQty DECIMAL(18, 4) = 0;
    DECLARE @MarkId CHAR(12) = '';
    DECLARE @IsManualFinish BIT = 0;

    IF ISNULL(@I_PKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:请先选择一张散件订单';
        RETURN -1;
    END;

    SELECT @OrderName = OrderName
    FROM dbo.KDOrderInfo
    WHERE KDOrderInfoId = @I_PKId
      AND OrderType IN ('8', '9', '10');

    IF ISNULL(@OrderName, N'') = N''
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:请选择一张国外CKD散件订单';
        RETURN -1;
    END;

    SELECT @PackQty = CONVERT(DECIMAL(18, 4), ISNULL(SUM(c.IssuedQty), 0))
    FROM dbo.KDOrderItem AS a
    INNER JOIN dbo.KDMOItem AS c ON c.KDOrderItemId = a.KDOrderItemId
    WHERE a.KDOrderInfoId = @I_PKId;

    EXEC dbo.KDOrderLoadedPull @KDOrderInfoId = @I_PKId;

    SELECT @LoadedQty = CONVERT(DECIMAL(18, 4), ISNULL(SUM(RealQty), 0))
    FROM dbo.KDOrderLoadedItem
    WHERE KDOrderInfoId = @I_PKId;

    IF @PackQty > 0 AND @PackQty = @LoadedQty
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:该订单已包装数与货柜明细已装柜数量一致，不能改回未完成';
        RETURN -1;
    END;

    BEGIN TRAN;

    SELECT @MarkId = KDOrderFinishMarkId,
           @IsManualFinish = IsManualFinish
    FROM dbo.KDOrderFinishMark WITH (UPDLOCK, HOLDLOCK)
    WHERE KDOrderInfoId = @I_PKId
      AND IsCancel = 0;

    IF ISNULL(@IsManualFinish, 0) = 1
    BEGIN
        UPDATE dbo.KDOrderFinishMark
        SET IsManualFinish = 0,
            ModifyDate = GETDATE()
        WHERE KDOrderFinishMarkId = @MarkId;

        SET @I_ReturnMessage = N'ServerMessage:已变更为未完成';
    END
    ELSE IF ISNULL(@MarkId, '') <> ''
    BEGIN
        UPDATE dbo.KDOrderFinishMark
        SET IsManualFinish = 1,
            ModifyDate = GETDATE()
        WHERE KDOrderFinishMarkId = @MarkId;

        SET @I_ReturnMessage = N'ServerMessage:已变更为已完成';
    END
    ELSE
    BEGIN
        EXEC dbo.SysGetObjectPKId
            @ObjectId = '',
            @ObjectName = N'KDOrderFinishMark',
            @PKID = @MarkId OUTPUT;

        INSERT INTO dbo.KDOrderFinishMark
        (
            KDOrderFinishMarkId, KDOrderInfoId, IsManualFinish,
            CreateUserId, CreateUserName, CreateDate, ModifyDate, IsCancel
        )
        VALUES
        (
            @MarkId, @I_PKId, 1,
            ISNULL(@I_OrBitUserId, ''), ISNULL(@I_OrBitUserName, N''), GETDATE(), GETDATE(), 0
        );

        SET @I_ReturnMessage = N'ServerMessage:已变更为已完成';
    END;

    COMMIT TRAN;
    RETURN 0;
END
GO
-- 基板正式。给国外 CKD 订单（KDYN）加上「变更完成状态」按钮。
-- 按钮挂在现有按钮组 MFG1000000XJ。过程 KDOrderFinishChangeDoMethod 需要先建好。

DECLARE @MethodId CHAR(12) = '';
DECLARE @TextId CHAR(12) = '';

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SysMetadataMethod
    WHERE MetadataFieldGroupId = 'MFG1000000XJ'
      AND MethodName = N'KDOrderFinishChange'
)
BEGIN
    EXEC dbo.SysGetObjectPKId
        @ObjectId = '',
        @ObjectName = N'SysMetadataMethod',
        @PKID = @MethodId OUTPUT;

    INSERT INTO dbo.SysMetadataMethod
    (
        MetadataMethodId, MetadataFieldGroupId, MethodSequence, MethodName, SQLDoMethod,
        IsBeforeRunningConfirm, PromptMessage, IsRefreshTreeView, IsPrintMethod, CreateDate
    )
    VALUES
    (
        @MethodId, 'MFG1000000XJ', '11', N'KDOrderFinishChange', N'KDOrderFinishChangeDoMethod',
        1, N'确认变更该散件订单的完成状态？', 1, 0, GETDATE()
    );
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SysText
    WHERE TextOwner = N'[Public Text]'
      AND TextModule = N'KDOrderFinishChange'
)
BEGIN
    EXEC dbo.SysGetObjectPKId
        @ObjectId = '',
        @ObjectName = N'SysText',
        @PKID = @TextId OUTPUT;

    INSERT INTO dbo.SysText
    (
        SysTextId, TextOwner, TextModule, TextControl, Text1, Text2, CreateDate, Protected
    )
    VALUES
    (
        @TextId, N'[Public Text]', N'KDOrderFinishChange', N'',
        N'KDOrderFinishChange', N'变更完成状态', GETDATE(), 0
    );
END;
GO
-- 基板正式。KDYN 散件订单列表增加完成状态。
-- 已包装数仍按这批订单汇总 KDMOItem.IssuedQty。
-- 已装柜数量先执行 KDOrderLoadedPull，再按 KDOrderInfoId 汇总 KDOrderLoadedItem.RealQty。
-- 手工标记在 KDOrderFinishMark。其他插件的列表分支保持原样。

ALTER PROCEDURE [dbo].[KDOrderInfoTreeView]
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,
    @I_LanguageId CHAR(1) = '1',
    @I_PlugInCommand VARCHAR(5) = '',
    @I_FiltCondition NVARCHAR(MAX) = '',
    @I_OrBitUserId CHAR(12) = '',
    @I_OrBitUserName NVARCHAR(100) = '',
    @I_ResourceId CHAR(12) = '',
    @I_ResourceName NVARCHAR(100) = '',
    @I_PKId CHAR(12) = '',
    @I_ParentPKId CHAR(12) = '',
    @I_Parameter NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @I_PlugInCommand = 'KDYN'
       OR EXISTS (
            SELECT 1
            FROM dbo.KDOrderInfo
            WHERE KDOrderInfoId = @I_PKId
              AND @I_PKId <> ''
              AND OrderType IN ('8', '9', '10')
       )
    BEGIN
        IF OBJECT_ID(N'tempdb..#Orders') IS NOT NULL DROP TABLE #Orders;
        IF OBJECT_ID(N'tempdb..#Pack') IS NOT NULL DROP TABLE #Pack;
        IF OBJECT_ID(N'tempdb..#Loaded') IS NOT NULL DROP TABLE #Loaded;

        CREATE TABLE #Orders
        (
            KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
            OrderName NVARCHAR(100) NOT NULL
        );
        CREATE TABLE #Pack
        (
            KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
            PackQty DECIMAL(18, 4) NOT NULL
        );
        CREATE TABLE #Loaded
        (
            KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
            LoadedQty DECIMAL(18, 4) NOT NULL
        );

        INSERT INTO #Orders (KDOrderInfoId, OrderName)
        SELECT KDOrderInfoId, OrderName
        FROM dbo.KDOrderInfo
        WHERE OrderType IN ('8', '9', '10')
          AND ISNULL(OrderName, N'') <> N''
          AND (@I_PKId = '' OR KDOrderInfoId = @I_PKId);

        INSERT INTO #Pack (KDOrderInfoId, PackQty)
        SELECT a.KDOrderInfoId, CONVERT(DECIMAL(18, 4), SUM(c.IssuedQty))
        FROM #Orders AS o
        INNER JOIN dbo.KDOrderItem AS a ON a.KDOrderInfoId = o.KDOrderInfoId
        INNER JOIN dbo.KDMOItem AS c ON c.KDOrderItemId = a.KDOrderItemId
        GROUP BY a.KDOrderInfoId;

        EXEC dbo.KDOrderLoadedPull @KDOrderInfoId = @I_PKId;

        INSERT INTO #Loaded (KDOrderInfoId, LoadedQty)
        SELECT t.KDOrderInfoId, CONVERT(DECIMAL(18, 4), SUM(t.RealQty))
        FROM dbo.KDOrderLoadedItem AS t
        INNER JOIN #Orders AS o ON o.KDOrderInfoId = t.KDOrderInfoId
        GROUP BY t.KDOrderInfoId;

        SELECT KDOrderInfo.KDOrderInfoId,
               KDOrderInfo.OrderName,
               CASE
                   WHEN ISNULL(pack.PackQty, 0) > 0
                        AND ISNULL(pack.PackQty, 0) = ISNULL(loaded.LoadedQty, 0) THEN N'已完成'
                   WHEN ISNULL(mark.IsManualFinish, 0) = 1 THEN N'已完成'
                   ELSE N'未完成'
               END AS '完成状态',
               OrderDescription,
               STUFF((
                   SELECT DISTINCT '; ' + MO.SOName
                   FROM KDMO
                   INNER JOIN MO ON KDMO.MOId = MO.MOId
                   WHERE KDMO.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
                   FOR XML PATH('')
               ), 1, 2, '') AS SOName,
               (
                   SELECT SUM(IIF(b.PalletSN IS NULL, 1, 0))
                   FROM KDPalletInfo AS a
                   LEFT JOIN ShipPallet AS b ON a.PalletSN = b.PalletSN AND b.IsCancel = 0
                   WHERE a.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
                   GROUP BY a.KDOrderInfoId
               ) AS '栈板未装箱数量',
               IIF(
                   (ISNULL(pack.PackQty, 0) > 0 AND ISNULL(pack.PackQty, 0) = ISNULL(loaded.LoadedQty, 0))
                   OR ISNULL(mark.IsManualFinish, 0) = 1,
                   '[RowColor:YDZ]',
                   '[RowColor:Y4Z]'
               ) AS ColorControlId
        FROM dbo.KDOrderInfo
        INNER JOIN #Orders AS chosen ON chosen.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
        LEFT JOIN #Pack AS pack ON pack.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
        LEFT JOIN #Loaded AS loaded ON loaded.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
        LEFT JOIN dbo.KDOrderFinishMark AS mark
            ON mark.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
           AND mark.IsCancel = 0
        ORDER BY KDOrderInfo.CreateDate DESC;

        RETURN 0;
    END;

    IF @I_PKId <> ''
    BEGIN
        SELECT KDOrderInfo.KDOrderInfoId,
               KDOrderInfo.OrderName,
               KDOrderInfo.OrderQty
        FROM KDOrderInfo
        WHERE KDOrderInfoId = @I_PKId;
        RETURN 0;
    END;

    IF @I_PlugInCommand = 'KDOI'
    BEGIN
        SELECT KDOrderInfo.KDOrderInfoId,
               KDOrderInfo.OrderName,
               KDOrderInfo.OrderQty,
               OrderDescription,
               CASE
                   WHEN EXISTS (
                       SELECT 1
                       FROM KDModuleOrder
                       WHERE KDOrderInfoId = KDOrderInfo.KDOrderInfoId
                   ) THEN ''
                   ELSE '[RowColor:X4Z]'
               END AS ColorControlId
        FROM KDOrderInfo
        WHERE OrderType = '1'
        ORDER BY KDOrderInfo.CreateDate DESC;
    END;

    IF @I_PlugInCommand = 'KDOIB'
    BEGIN
        SELECT KDOrderInfo.KDOrderInfoId,
               CASE WHEN IsCancel = 1 THEN '报废单' ELSE '正常' END AS '单据状态',
               KDOrderInfo.OrderName,
               KDOrderInfo.OrderQty,
               OrderDescription,
               (
                   SELECT SUM(IIF(b.PalletSN IS NULL, 1, 0))
                   FROM KDPalletInfo AS a
                   LEFT JOIN ShipPallet AS b ON a.PalletSN = b.PalletSN AND b.IsCancel = 0
                   WHERE a.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
                   GROUP BY a.KDOrderInfoId
               ) AS '栈板未装箱数量'
        FROM KDOrderInfo
        WHERE OrderType = '2'
          AND CreateDate > DATEADD(MONTH, -12, GETDATE())
        ORDER BY KDOrderInfo.CreateDate DESC;
    END;

    IF @I_PlugInCommand = 'KDOF'
    BEGIN
        SELECT KDOrderInfo.KDOrderInfoId,
               KDOrderInfo.OrderName,
               KDOrderInfo.OrderQty,
               OrderDescription
        FROM KDOrderInfo
        WHERE OrderType = '3'
        ORDER BY KDOrderInfo.CreateDate DESC;
    END;

    RETURN 0;
END
GO
