-- 基板正式。散件订单增加完成状态。0 未完成，1 已完成。
-- 列表发现未完成但已包装数等于已装柜数量时，写成 1。
-- 若 KDOrderFinishMark 里已有手工完成，先抄过来，再删掉那张表。

IF COL_LENGTH(N'dbo.KDOrderInfo', N'IsManualFinish') IS NULL
BEGIN
    ALTER TABLE [dbo].[KDOrderInfo]
        ADD [IsManualFinish] BIT NOT NULL
            CONSTRAINT [DF_KDOrderInfo_IsManualFinish] DEFAULT 0;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE name = N'MS_Description'
      AND major_id = OBJECT_ID(N'dbo.KDOrderInfo')
      AND minor_id = COLUMNPROPERTY(OBJECT_ID(N'dbo.KDOrderInfo'), N'IsManualFinish', 'ColumnId')
)
BEGIN
    EXEC sp_addextendedproperty
        @name = N'MS_Description', @value = N'完成状态。0 未完成，1 已完成',
        @level0type = N'SCHEMA', @level0name = N'dbo',
        @level1type = N'TABLE',  @level1name = N'KDOrderInfo',
        @level2type = N'COLUMN', @level2name = N'IsManualFinish';
END
GO

IF OBJECT_ID(N'dbo.KDOrderFinishMark', N'U') IS NOT NULL
BEGIN
    UPDATE info
    SET IsManualFinish = 1
    FROM dbo.KDOrderInfo AS info
    INNER JOIN dbo.KDOrderFinishMark AS mark
        ON mark.KDOrderInfoId = info.KDOrderInfoId
    WHERE mark.IsCancel = 0
      AND mark.IsManualFinish = 1
      AND ISNULL(info.IsManualFinish, 0) = 0;
END
GO
