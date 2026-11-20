-- 基板正式一次性拉取。先补索引，再把国外 CKD 订单已装柜明细写入 KDOrderLoadedItem。
-- 表里已有的 KDBoxItemId 不会再插。在基板正式执行。

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

DECLARE @Names NVARCHAR(MAX) = N'';
DECLARE @Remote NVARCHAR(MAX) = N'';
DECLARE @Sql NVARCHAR(MAX) = N'';

SELECT @Names = STUFF((
    SELECT N',N''' + REPLACE(OrderName, '''', '''''') + N''''
    FROM dbo.KDOrderInfo
    WHERE OrderType IN ('8', '9', '10')
      AND ISNULL(OrderName, N'') <> N''
    FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 1, N'');

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
WHERE z.OrderName IN (' + @Names + N')';

SET @Sql = N'
INSERT INTO dbo.KDOrderLoadedItem
    (KDBoxItemId, KDOrderInfoId, OrderName, RealQty, Container, IssuerDate)
SELECT s.KDBoxItemId,
       MIN(o.KDOrderInfoId),
       MIN(s.OrderName),
       MAX(CONVERT(decimal(18, 4), s.RealQty)),
       MAX(s.Container),
       MAX(CASE WHEN s.IssuerDate = '''' THEN CONVERT(datetime, ''19000101'') ELSE CONVERT(datetime, s.IssuerDate) END)
FROM OPENQUERY([172.16.8.31], ''' + REPLACE(@Remote, '''', '''''') + N''') AS s
INNER JOIN dbo.KDOrderInfo AS o
    ON o.OrderName = s.OrderName
   AND o.OrderType IN (''8'', ''9'', ''10'')
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.KDOrderLoadedItem AS t
    WHERE t.KDBoxItemId = s.KDBoxItemId
)
GROUP BY s.KDBoxItemId;';

EXEC (@Sql);

SELECT COUNT(*) AS loaded_rows
FROM dbo.KDOrderLoadedItem;
GO
