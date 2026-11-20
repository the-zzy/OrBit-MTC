-- 基板正式。V2：拉取数量从「装柜数量」改为「配载数量」。
--
-- 旧版来源：总装 KDBoxInfo + KDBoxItem（Container 非空、IsCancel=0），
--           数量取 KDBoxItem.RealQty，即实际装柜/装箱数量。
-- 新版来源：总装 ContainerItem + ContainerInfo（IsCancel=0、ContainerSN 非空），
--           数量取 ContainerItem.RealQty，即货柜明细上的「配载数量」。
--
-- 说明：
-- 1. KDOrderLoadedItem.KDBoxItemId 是快照的来源主键列。本版把 ContainerItemId
--    写入该列（两者都是 char(12) 且唯一），表结构不变。列名是历史命名。
-- 2. IssuerDate 取配载记录的修改时间（有修改取修改时间，否则取创建时间），
--    这样配载数量被调整后，增量拉取能重新取到。
-- 3. 只取已挂真实货柜号（ContainerSN 非空）的配载，草稿柜/空货柜号不参与。
-- 4. 旧快照行（KDBoxItemId 存的是箱明细主键，JDB 前缀）会被识别为旧来源：
--    本过程对该订单先删旧行再全量拉配载，避免新旧来源重复累计。
--    KDOrderLoadedItem_RepullFromAlloc.sql 可一次性把所有订单刷新为配载来源。

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
GO
