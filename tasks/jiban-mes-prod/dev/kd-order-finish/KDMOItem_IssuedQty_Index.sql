-- 基板正式。KDMOItem 按订单组件汇总已包装数时，现有索引不含 IssuedQty，每次都要回表。
-- 企业版在线建索引，装箱写入不必等这次建索引结束。
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_KDMOItem_KDOrderItemId_IssuedQty'
      AND object_id = OBJECT_ID(N'dbo.KDMOItem')
)
    CREATE NONCLUSTERED INDEX IX_KDMOItem_KDOrderItemId_IssuedQty
    ON dbo.KDMOItem (KDOrderItemId)
    INCLUDE (IssuedQty)
    WITH (ONLINE = ON, SORT_IN_TEMPDB = ON);
GO
