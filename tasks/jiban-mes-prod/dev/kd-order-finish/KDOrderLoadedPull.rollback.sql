
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
        ContainerItemId CHAR(12) NOT NULL,
        RealQty DECIMAL(18, 4) NOT NULL,
        Container VARCHAR(30) NOT NULL,
        IssuerDate DATETIME NOT NULL
    );

    -- 已有快照的订单只有在「全部来源都是配载（CIT 前缀）」时才做增量；
    -- 仍含旧箱明细来源（JDB 前缀）的订单按新单处理，先清旧行再全量拉配载。
    INSERT INTO #LoadedPullOrder (KDOrderInfoId, OrderName, IsNew)
    SELECT o.KDOrderInfoId,
           o.OrderName,
           CASE
               WHEN EXISTS (
                   SELECT 1
                   FROM dbo.KDOrderLoadedItem AS t
                   WHERE t.KDOrderInfoId = o.KDOrderInfoId
               )
               AND NOT EXISTS (
                   SELECT 1
                   FROM dbo.KDOrderLoadedItem AS t
                   WHERE t.KDOrderInfoId = o.KDOrderInfoId
                     AND t.KDBoxItemId NOT LIKE N'CIT%'
               ) THEN 0
               ELSE 1
           END
    FROM dbo.KDOrderInfo AS o
    WHERE o.OrderType IN ('8', '9', '10')
      AND ISNULL(o.OrderName, N'') <> N''
      AND (@KDOrderInfoId = '' OR o.KDOrderInfoId = @KDOrderInfoId)
      AND (@OnlyOpen = 0 OR ISNULL(o.IsManualFinish, 0) = 0);

    -- 按配载重拉的订单，先删掉旧的箱明细来源行，避免两种来源重复累计。
    -- KDBoxItemId 列现在存放来源主键：箱明细为 JDB 前缀，配载明细为 CIT 前缀。
    DELETE t
    FROM dbo.KDOrderLoadedItem AS t
    INNER JOIN #LoadedPullOrder AS p ON p.KDOrderInfoId = t.KDOrderInfoId
    WHERE p.IsNew = 1
      AND t.KDBoxItemId NOT LIKE N'CIT%';

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
       ci.ContainerItemId,
       CONVERT(varchar(40), ci.RealQty) AS RealQty,
       ISNULL(c.ContainerSN, '''') AS Container,
       ISNULL(CONVERT(varchar(19), ISNULL(ci.ModifyDate, ci.CreateDate), 120), '''') AS IssuerDate
FROM OrBitXIZC.dbo.KDOrderInfo AS z WITH (NOLOCK)
INNER JOIN OrBitXIZC.dbo.ContainerItem AS ci WITH (NOLOCK)
    ON ci.KDOrderInfoId = z.KDOrderInfoId
   AND ci.IsCancel = 0
INNER JOIN OrBitXIZC.dbo.ContainerInfo AS c WITH (NOLOCK)
    ON c.ContainerInfoId = ci.ContainerInfoId
   AND c.IsCancel = 0
   AND ISNULL(c.ContainerSN, '''') <> ''''
WHERE ' + @Where;
        SET @Sql = N'INSERT INTO #LoadedStage (OrderName, ContainerItemId, RealQty, Container, IssuerDate)
SELECT OrderName,
       ContainerItemId,
       CONVERT(decimal(18, 4), RealQty),
       Container,
       CASE WHEN IssuerDate = '''' THEN CONVERT(datetime, ''19000101'') ELSE CONVERT(datetime, IssuerDate) END
FROM OPENQUERY([172.16.8.31], ''' + REPLACE(@Remote, '''', '''''') + N''')';
        EXEC (@Sql);
    END;

    IF ISNULL(@OldNames, N'') <> N''
    BEGIN
        IF @Mark IS NOT NULL
            SET @Where = N'z.OrderName IN (' + @OldNames + N') AND ISNULL(ci.ModifyDate, ci.CreateDate) >= '''
                + CONVERT(VARCHAR(19), @Mark, 120) + N'''';
        ELSE
            SET @Where = N'z.OrderName IN (' + @OldNames + N')';
        SET @Remote = N'
SELECT z.OrderName,
       ci.ContainerItemId,
       CONVERT(varchar(40), ci.RealQty) AS RealQty,
       ISNULL(c.ContainerSN, '''') AS Container,
       ISNULL(CONVERT(varchar(19), ISNULL(ci.ModifyDate, ci.CreateDate), 120), '''') AS IssuerDate
FROM OrBitXIZC.dbo.KDOrderInfo AS z WITH (NOLOCK)
INNER JOIN OrBitXIZC.dbo.ContainerItem AS ci WITH (NOLOCK)
    ON ci.KDOrderInfoId = z.KDOrderInfoId
   AND ci.IsCancel = 0
INNER JOIN OrBitXIZC.dbo.ContainerInfo AS c WITH (NOLOCK)
    ON c.ContainerInfoId = ci.ContainerInfoId
   AND c.IsCancel = 0
   AND ISNULL(c.ContainerSN, '''') <> ''''
WHERE ' + @Where;
        SET @Sql = N'INSERT INTO #LoadedStage (OrderName, ContainerItemId, RealQty, Container, IssuerDate)
SELECT OrderName,
       ContainerItemId,
       CONVERT(decimal(18, 4), RealQty),
       Container,
       CASE WHEN IssuerDate = '''' THEN CONVERT(datetime, ''19000101'') ELSE CONVERT(datetime, IssuerDate) END
FROM OPENQUERY([172.16.8.31], ''' + REPLACE(@Remote, '''', '''''') + N''')';
        EXEC (@Sql);
    END;

    MERGE dbo.KDOrderLoadedItem AS t
    USING (
        SELECT s.ContainerItemId,
               MIN(p.KDOrderInfoId) AS KDOrderInfoId,
               MIN(s.OrderName) AS OrderName,
               MAX(s.RealQty) AS RealQty,
               MAX(s.Container) AS Container,
               MAX(s.IssuerDate) AS IssuerDate
        FROM #LoadedStage AS s
        INNER JOIN #LoadedPullOrder AS p ON p.OrderName = s.OrderName
        GROUP BY s.ContainerItemId
    ) AS s
        ON t.KDBoxItemId = s.ContainerItemId
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
        VALUES (s.ContainerItemId, s.KDOrderInfoId, s.OrderName, s.RealQty, s.Container, s.IssuerDate, GETDATE(), GETDATE());

    RETURN 0;
END
