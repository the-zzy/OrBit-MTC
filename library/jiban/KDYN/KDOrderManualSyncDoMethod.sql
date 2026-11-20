
CREATE PROCEDURE [dbo].[KDOrderManualSyncDoMethod]
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
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @NewRows INT = 0;
    DECLARE @FinishNames NVARCHAR(MAX) = N'';

    IF OBJECT_ID(N'dbo.KDOrderLoadedPull', N'P') IS NULL
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:缺少 KDOrderLoadedPull，请先部署增量拉取过程';
        RETURN -1;
    END;

    IF OBJECT_ID(N'tempdb..#SyncOrder') IS NOT NULL DROP TABLE #SyncOrder;
    IF OBJECT_ID(N'tempdb..#BeforeItem') IS NOT NULL DROP TABLE #BeforeItem;
    IF OBJECT_ID(N'tempdb..#FinishOrder') IS NOT NULL DROP TABLE #FinishOrder;

    -- 同步范围固定为全部未完成的国外 CKD 散件订单，选择行与否都走这里。
    CREATE TABLE #SyncOrder
    (
        KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
        OrderName NVARCHAR(100) NOT NULL
    );

    INSERT INTO #SyncOrder (KDOrderInfoId, OrderName)
    SELECT o.KDOrderInfoId, o.OrderName
    FROM dbo.KDOrderInfo AS o
    WHERE o.OrderType IN ('8', '9', '10')
      AND ISNULL(o.OrderName, N'') <> N''
      AND ISNULL(o.IsManualFinish, 0) = 0;

    -- 同步前已有快照主键。整单重拉会先删旧来源行，用主键差集统计新增更准确。
    CREATE TABLE #BeforeItem
    (
        KDBoxItemId CHAR(12) NOT NULL PRIMARY KEY
    );

    INSERT INTO #BeforeItem (KDBoxItemId)
    SELECT t.KDBoxItemId
    FROM dbo.KDOrderLoadedItem AS t
    INNER JOIN #SyncOrder AS o ON o.KDOrderInfoId = t.KDOrderInfoId;

    BEGIN TRY
        EXEC dbo.KDOrderLoadedPull @OnlyOpen = 1;
    END TRY
    BEGIN CATCH
        SET @I_ReturnMessage = N'ServerMessage:同步失败：' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH;

    SELECT @NewRows = COUNT(*)
    FROM dbo.KDOrderLoadedItem AS t
    INNER JOIN #SyncOrder AS o ON o.KDOrderInfoId = t.KDOrderInfoId
    WHERE NOT EXISTS (
        SELECT 1
        FROM #BeforeItem AS b
        WHERE b.KDBoxItemId = t.KDBoxItemId
    );

    -- 与 KDOrderInfoTreeView 自动完成口径一致：未完成且 包装数 = 配载数 > 0。
    CREATE TABLE #FinishOrder
    (
        KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
        OrderName NVARCHAR(100) NOT NULL
    );

    INSERT INTO #FinishOrder (KDOrderInfoId, OrderName)
    SELECT o.KDOrderInfoId, o.OrderName
    FROM #SyncOrder AS o
    INNER JOIN dbo.KDOrderInfo AS info ON info.KDOrderInfoId = o.KDOrderInfoId
    LEFT JOIN (
        SELECT i.KDOrderInfoId, SUM(m.IssuedQty) AS PackQty
        FROM dbo.KDOrderItem AS i
        INNER JOIN dbo.KDMOItem AS m ON m.KDOrderItemId = i.KDOrderItemId
        GROUP BY i.KDOrderInfoId
    ) AS p ON p.KDOrderInfoId = o.KDOrderInfoId
    LEFT JOIN (
        SELECT t.KDOrderInfoId, SUM(t.RealQty) AS LoadedQty
        FROM dbo.KDOrderLoadedItem AS t
        GROUP BY t.KDOrderInfoId
    ) AS l ON l.KDOrderInfoId = o.KDOrderInfoId
    WHERE ISNULL(info.IsManualFinish, 0) = 0
      AND ISNULL(p.PackQty, 0) > 0
      AND ISNULL(p.PackQty, 0) = ISNULL(l.LoadedQty, 0);

    IF EXISTS (SELECT 1 FROM #FinishOrder)
    BEGIN
        UPDATE info
        SET IsManualFinish = 1
        FROM dbo.KDOrderInfo AS info
        INNER JOIN #FinishOrder AS f ON f.KDOrderInfoId = info.KDOrderInfoId
        WHERE ISNULL(info.IsManualFinish, 0) = 0;

        SELECT @FinishNames = STUFF((
            SELECT CHAR(13) + CHAR(10) + N'工单【' + f.OrderName + N'】变更状态为已完成'
            FROM #FinishOrder AS f
            ORDER BY f.OrderName
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 2, N'');
    END;

    SET @I_ReturnMessage = N'ServerMessage:新增数据' + CONVERT(NVARCHAR(20), @NewRows) + N'行'
        + CASE WHEN ISNULL(@FinishNames, N'') = N'' THEN N''
               ELSE CHAR(13) + CHAR(10) + @FinishNames
          END;

    RETURN 0;
END
