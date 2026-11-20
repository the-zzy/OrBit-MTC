-- 基板正式。KDYN 散件订单「变更完成状态」。
-- 仅 GC1005 账号可执行，过程内直接按 SysUser.UserName 判权。
-- 手动锁定 / 手动解锁都不做数量或其他逻辑管控，只切换 IsManualFinish。
-- 用途：装箱人员需要继续装箱时，通知管理者手动解锁。
-- 自动锁定逻辑保留在定时任务和「手动同步数据」按钮（KDOrderManualSyncDoMethod）里。
-- 完成状态写在 KDOrderInfo.IsManualFinish。

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
    DECLARE @IsManualFinish BIT = 0;
    DECLARE @NextFinish BIT = 0;
    DECLARE @AllowedUserId CHAR(12) = '';

    -- 只有 GC1005 可以手动变更完成状态。
    SELECT @AllowedUserId = UserId
    FROM dbo.SysUser
    WHERE UserName = N'GC1005'
      AND ISNULL(IsCancel, 0) = 0
      AND IsActivity = 1;

    IF ISNULL(@AllowedUserId, '') = N''
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:未找到启用的 GC1005 账号，不能变更完成状态';
        RETURN -1;
    END;

    IF ISNULL(@I_OrBitUserId, '') <> @AllowedUserId
       AND ISNULL(@I_OrBitUserName, N'') <> N'GC1005'
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:只有 GC1005 可以手动变更完成状态';
        RETURN -1;
    END;

    IF ISNULL(@I_PKId, '') = ''
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:请先选择一张散件订单';
        RETURN -1;
    END;

    SELECT @OrderName = OrderName,
           @IsManualFinish = ISNULL(IsManualFinish, 0)
    FROM dbo.KDOrderInfo
    WHERE KDOrderInfoId = @I_PKId
      AND OrderType IN ('8', '9', '10');

    IF ISNULL(@OrderName, N'') = N''
    BEGIN
        SET @I_ReturnMessage = N'ServerMessage:请选择一张国外CKD散件订单';
        RETURN -1;
    END;

    SET @NextFinish = CASE WHEN ISNULL(@IsManualFinish, 0) = 1 THEN 0 ELSE 1 END;

    UPDATE dbo.KDOrderInfo
    SET IsManualFinish = @NextFinish
    WHERE KDOrderInfoId = @I_PKId;

    IF @NextFinish = 1
        SET @I_ReturnMessage = N'ServerMessage:已变更为已完成';
    ELSE
        SET @I_ReturnMessage = N'ServerMessage:已变更为未完成';

    RETURN 0;
END
GO
