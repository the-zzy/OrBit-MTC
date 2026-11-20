-- 基板正式。一次性把 KDOrderLoadedItem 的存量快照从「装柜数量」刷新为「配载数量」。
-- 前提：已部署 KDOrderLoadedPull_V2_alloc.sql。
--
-- 执行内容：
-- 1. 备份现有快照到 KDOrderLoadedItem_BAK20261119（只建一次）。
-- 2. 清空 KDOrderLoadedItem。
-- 3. 调用 KDOrderLoadedPull 全量重拉（按总装 ContainerItem.RealQty）。
--
-- 影响：完成后 KDYN 列表的「已装柜数量」= 配载数量。
-- 全量重拉后，KDOrderInfoTreeView 打开列表时会把「包装数 = 配载数」的单自动置为已完成。
-- 建议先跑下面的对比查询确认差异，再执行第 2、3 步。

-- 0. 重拉前对比（只读，可单独执行）
-- SELECT o.OrderName, o.IsManualFinish,
--        CONVERT(DECIMAL(18,4), ISNULL(p.PackQty,0)) AS PackQty,
--        CONVERT(DECIMAL(18,4), ISNULL(l.LoadedQty,0)) AS LoadedQty
-- FROM dbo.KDOrderInfo o
-- LEFT JOIN (
--     SELECT i.KDOrderInfoId, SUM(m.IssuedQty) AS PackQty
--     FROM dbo.KDOrderItem i
--     INNER JOIN dbo.KDMOItem m ON m.KDOrderItemId = i.KDOrderItemId
--     GROUP BY i.KDOrderInfoId
-- ) p ON p.KDOrderInfoId = o.KDOrderInfoId
-- LEFT JOIN (
--     SELECT KDOrderInfoId, SUM(RealQty) AS LoadedQty
--     FROM dbo.KDOrderLoadedItem GROUP BY KDOrderInfoId
-- ) l ON l.KDOrderInfoId = o.KDOrderInfoId
-- WHERE o.OrderType IN ('8','9','10') AND ISNULL(o.IsCancel,0)=0
-- ORDER BY o.CreateDate DESC;

-- 1. 备份（表已存在则跳过）
IF OBJECT_ID(N'dbo.KDOrderLoadedItem_BAK20261119', N'U') IS NULL
BEGIN
    SELECT *
    INTO dbo.KDOrderLoadedItem_BAK20261119
    FROM dbo.KDOrderLoadedItem;
END;
GO

-- 2. 清空旧快照
DELETE FROM dbo.KDOrderLoadedItem;
GO

-- 3. 按配载全量重拉
EXEC dbo.KDOrderLoadedPull
    @KDOrderInfoId = '',
    @OnlyOpen = 0;
GO

-- 4. 结果核对
SELECT COUNT(*) AS Rows,
       COUNT(DISTINCT KDOrderInfoId) AS Orders,
       SUM(CASE WHEN KDBoxItemId LIKE N'CIT%' THEN 1 ELSE 0 END) AS AllocRows,
       SUM(CASE WHEN KDBoxItemId NOT LIKE N'CIT%' THEN 1 ELSE 0 END) AS OldSourceRows
FROM dbo.KDOrderLoadedItem;
GO
