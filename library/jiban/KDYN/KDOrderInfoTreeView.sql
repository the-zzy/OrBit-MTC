-- 基板正式。KDYN 散件订单列表增加完成状态。
-- 已包装数只汇总未完成订单的 KDMOItem.IssuedQty。已完成订单直接读状态。
-- 已装柜数量只汇总基板本地 KDOrderLoadedItem.RealQty，列表不访问总装。
-- 完成状态在 KDOrderInfo.IsManualFinish。未完成且两边数量已经相等的订单，打开列表时写成已完成。
-- 其他插件的列表分支保持原样。

CREATE PROCEDURE [dbo].[KDOrderInfoTreeView]
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
        CREATE TABLE #Pallet
        (
            KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
            OpenPalletQty INT NULL
        );
        CREATE TABLE #SaleOrder
        (
            KDOrderInfoId CHAR(12) NOT NULL PRIMARY KEY,
            SOName NVARCHAR(MAX) NULL
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
        INNER JOIN dbo.KDOrderInfo AS info ON info.KDOrderInfoId = o.KDOrderInfoId
        INNER JOIN dbo.KDOrderItem AS a ON a.KDOrderInfoId = o.KDOrderInfoId
        INNER JOIN dbo.KDMOItem AS c ON c.KDOrderItemId = a.KDOrderItemId
        WHERE ISNULL(info.IsManualFinish, 0) = 0
        GROUP BY a.KDOrderInfoId;

        INSERT INTO #Loaded (KDOrderInfoId, LoadedQty)
        SELECT t.KDOrderInfoId, CONVERT(DECIMAL(18, 4), SUM(t.RealQty))
        FROM dbo.KDOrderLoadedItem AS t
        INNER JOIN #Orders AS o ON o.KDOrderInfoId = t.KDOrderInfoId
        GROUP BY t.KDOrderInfoId;

        INSERT INTO #Pallet (KDOrderInfoId, OpenPalletQty)
        SELECT a.KDOrderInfoId, SUM(IIF(b.PalletSN IS NULL, 1, 0))
        FROM #Orders AS o
        INNER JOIN dbo.KDPalletInfo AS a ON a.KDOrderInfoId = o.KDOrderInfoId
        LEFT JOIN dbo.ShipPallet AS b WITH (FORCESEEK)
            ON b.PalletSN = a.PalletSN AND b.IsCancel = 0
        GROUP BY a.KDOrderInfoId;

        INSERT INTO #SaleOrder (KDOrderInfoId, SOName)
        SELECT o.KDOrderInfoId,
               STUFF((
                   SELECT DISTINCT '; ' + MO.SOName
                   FROM dbo.KDMO
                   INNER JOIN dbo.MO ON KDMO.MOId = MO.MOId
                   WHERE KDMO.KDOrderInfoId = o.KDOrderInfoId
                   FOR XML PATH('')
               ), 1, 2, '')
        FROM #Orders AS o;

        UPDATE info
        SET IsManualFinish = 1
        FROM dbo.KDOrderInfo AS info
        INNER JOIN #Orders AS o ON o.KDOrderInfoId = info.KDOrderInfoId
        INNER JOIN #Pack AS pack ON pack.KDOrderInfoId = info.KDOrderInfoId
        INNER JOIN #Loaded AS loaded ON loaded.KDOrderInfoId = info.KDOrderInfoId
        WHERE ISNULL(info.IsManualFinish, 0) = 0
          AND pack.PackQty > 0
          AND pack.PackQty = loaded.LoadedQty;

        SELECT KDOrderInfo.KDOrderInfoId,
               KDOrderInfo.OrderName,
               CASE
                   WHEN ISNULL(KDOrderInfo.IsManualFinish, 0) = 1 THEN N'已完成'
                   ELSE N'未完成'
               END AS '完成状态',
               OrderDescription,
               sale.SOName,
               pallet.OpenPalletQty AS '栈板未装箱数量',
               IIF(ISNULL(KDOrderInfo.IsManualFinish, 0) = 1, '[RowColor:YDZ]', '[RowColor:Y4Z]') AS ColorControlId
        FROM dbo.KDOrderInfo
        INNER JOIN #Orders AS chosen ON chosen.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
        LEFT JOIN #SaleOrder AS sale ON sale.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
        LEFT JOIN #Pallet AS pallet ON pallet.KDOrderInfoId = KDOrderInfo.KDOrderInfoId
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