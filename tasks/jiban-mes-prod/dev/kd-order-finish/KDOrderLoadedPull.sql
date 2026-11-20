-- 基板正式。从总装拉取已装柜装箱明细，写入 KDOrderLoadedItem。
-- 订单还没有本地明细时全量拉取。已有明细的订单只拉 IssuerDate 不早于上次最大装柜时间的行。
-- 这两类订单分两次查询。合成一条 OR 时，总装会走慢计划。
-- 同一条总装装箱明细再次扫柜时按 KDBoxItemId 更新，不另插一行。
-- 依赖 KDOrderLoadedItem 已建表。链接服务器 [172.16.8.31]。

IF OBJECT_ID(N'dbo.KDOrderLoadedPull', N'P') IS NOT NULL
    DROP PROCEDURE dbo.KDOrderLoadedPull;
GO

CREATE PROCEDURE [dbo].[KDOrderLoadedPull]
    @KDOrderInfoId CHAR(12) = '',
    @OnlyOpen BIT = 0
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
      AND (@KDOrderInfoId = '' OR o.KDOrderInfoId = @KDOrderInfoId)
      AND (@OnlyOpen = 0 OR ISNULL(o.IsManualFinish, 0) = 0);

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

    IF ISNULL(@NewNames, N'') = N'' AND ISNULL(@OldNames, N'') = N''
        RETURN 0;

    IF ISNULL(@NewNames, N'') <> N''
    BEGIN
        SET @Where = N'z.OrderName IN (' + @NewNames + N')';
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
    END;

    IF ISNULL(@OldNames, N'') <> N''
    BEGIN
        IF @Mark IS NOT NULL
            SET @Where = N'z.OrderName IN (' + @OldNames + N') AND box.IssuerDate >= '''
                + CONVERT(VARCHAR(19), @Mark, 120) + N'''';
        ELSE
            SET @Where = N'z.OrderName IN (' + @OldNames + N')';
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
    END;

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
