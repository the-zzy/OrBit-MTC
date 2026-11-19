-- 基板正式。KDYN 散件订单「变更完成状态」。
-- 未完成直接改为已完成，不核对数量。
-- 已完成改回未完成时，用基板本地已装柜数量核对，不访问总装。数量一致则不允许。
-- 完成状态写在 KDOrderInfo.IsManualFinish。
-- 依赖 KDOrderInfo.IsManualFinish、KDOrderLoadedItem 已建好。

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
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @OrderName NVARCHAR(100) = N'';
    DECLARE @PackQty DECIMAL(18, 4) = 0;
    DECLARE @LoadedQty DECIMAL(18, 4) = 0;
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

    SELECT @IsManualFinish = ISNULL(IsManualFinish, 0)
    FROM dbo.KDOrderInfo
    WHERE KDOrderInfoId = @I_PKId;

    IF ISNULL(@IsManualFinish, 0) = 0
    BEGIN
        UPDATE dbo.KDOrderInfo
        SET IsManualFinish = 1
        WHERE KDOrderInfoId = @I_PKId;

        SET @I_ReturnMessage = N'ServerMessage:已变更为已完成';
        RETURN 0;
    END;

    SELECT @PackQty = CONVERT(DECIMAL(18, 4), ISNULL(SUM(c.IssuedQty), 0))
    FROM dbo.KDOrderItem AS a
    INNER JOIN dbo.KDMOItem AS c ON c.KDOrderItemId = a.KDOrderItemId
    WHERE a.KDOrderInfoId = @I_PKId;

    SELECT @LoadedQty = CONVERT(DECIMAL(18, 4), ISNULL(SUM(RealQty), 0))
    FROM dbo.KDOrderLoadedItem
    WHERE KDOrderInfoId = @I_PKId;

    IF @PackQty > 0 AND @PackQty = @LoadedQty
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:该订单已包装数与货柜明细已装柜数量一致，不能改回未完成';
        RETURN -1;
    END;

    UPDATE dbo.KDOrderInfo
    SET IsManualFinish = 0
    WHERE KDOrderInfoId = @I_PKId;

    SET @I_ReturnMessage = N'ServerMessage:已变更为未完成';

    RETURN 0;
END
GO
