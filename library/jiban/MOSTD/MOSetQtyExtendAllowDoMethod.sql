-- =============================================
-- Author:      1003153
-- Create date: 2026-10-08
-- Description: MOSTD · 设置工单延号允许数量(额外)，含操作密码与变更历史
-- =============================================
CREATE  PROCEDURE [dbo].[MOSetQtyExtendAllowDoMethod]
    @I_Sender NVARCHAR(200) = '',
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId CHAR(1) = '1',
    @I_PlugInCommand VARCHAR(5) = '',
    @I_OrBitUserId CHAR(12) = '',
    @I_OrBitUserName NVARCHAR(100) = '',
    @I_ResourceId CHAR(12) = '',
    @I_ResourceName NVARCHAR(100) = '',
    @I_PKid CHAR(12) = '',
    @I_ParentPKId CHAR(12) = '',
    @I_Parameter NVARCHAR(100) = '',
    @MOQtyExtendAllow BIGINT = 0,
    @ExtendAllowPassword NVARCHAR(50) = ''
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET XACT_ABORT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        SET @I_ReturnMessage = N'';
        SET @I_ExceptionFieldName = N'';

        DECLARE @return_value INT;
        DECLARE @MOId CHAR(12) = LTRIM(RTRIM(ISNULL(@I_PKid, N'')));
        DECLARE @MOName NVARCHAR(50);
        DECLARE @MOQtyRequired DECIMAL(18, 4);
        DECLARE @ProductId CHAR(12);
        DECLARE @StartedQty DECIMAL(18, 4);
        DECLARE @OldExtend BIGINT;
        DECLARE @Pwd NVARCHAR(50) = LTRIM(RTRIM(ISNULL(@ExtendAllowPassword, N'')));

        --EXEC @return_value = dbo.MetadataPermissionCheckDoMethod
        --    @I_ReturnMessage = @I_ReturnMessage OUTPUT,
        --    @I_OrBitUserId = @I_OrBitUserId,
        --    @I_OrBitUserName = @I_OrBitUserName,
        --    @I_Sender = @I_Sender;
        --IF @return_value = -1
        --    RETURN -1;

        IF @MOId = N''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:请选择工单';
            RETURN -1;
        END;

        /* 操作密码（用户代码：用户密码 → 延号允许数量设置密码） */
        IF @Pwd = N''
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:请输入操作密码';
            SET @I_ExceptionFieldName = N'ExtendAllowPassword';
            RETURN -1;
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.UserCode WITH (NOLOCK)
            WHERE ParentUserCodeId = N'URC1000002JP'
              AND UserCodeName = N'延号允许数量设置密码'
              AND UserCodeDescription = @Pwd
        )
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:操作密码错误';
            SET @I_ExceptionFieldName = N'ExtendAllowPassword';
            RETURN -1;
        END;

        IF @MOQtyExtendAllow < 0
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:延号允许数量不能小于 0';
            SET @I_ExceptionFieldName = N'MOQtyExtendAllow';
            RETURN -1;
        END;

        SELECT @MOQtyRequired = mo.MOQtyRequired,
               @ProductId = mo.ProductId,
               @OldExtend = mo.MOQtyExtendAllow,
               @MOName = mo.MOName
        FROM dbo.MO AS mo WITH (NOLOCK)
        WHERE mo.MOId = @MOId;

        IF @MOQtyRequired IS NULL
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:工单不存在';
            RETURN -1;
        END;

        IF @OldExtend = @MOQtyExtendAllow
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:延号允许数量未变化';
            RETURN 0;
        END;

        SELECT @StartedQty = ISNULL(SUM(mil.LotQty), 0)
        FROM dbo.MOItem AS mi WITH (NOLOCK)
        INNER JOIN dbo.MOItemLot AS mil WITH (NOLOCK) ON mil.MOItemId = mi.MOItemId
        WHERE mi.MOId = @MOId
          AND mi.ProductId = @ProductId
          AND mi.DeleteFlag <> N'X';

        IF CAST(@MOQtyRequired AS BIGINT) + @MOQtyExtendAllow < CAST(@StartedQty AS BIGINT)
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:需求数量+延号允许数量不能小于已启动数量 '
                + CAST(CAST(@StartedQty AS BIGINT) AS NVARCHAR(30))
                + N'，请加大延号允许数量或先处理已启动批号';
            SET @I_ExceptionFieldName = N'MOQtyExtendAllow';
            RETURN -1;
        END;

        IF OBJECT_ID(N'dbo.MOQtyExtendAllowLog', N'U') IS NULL
        BEGIN
            SET @I_ReturnMessage = N'ServerMessage:变更历史表未创建，请先执行 MOQtyExtendAllowLog_MTable.sql';
            RETURN -1;
        END;

        BEGIN TRANSACTION;

        UPDATE dbo.MO
        SET MOQtyExtendAllow = @MOQtyExtendAllow,
            ModifyDate = GETDATE()
        WHERE MOId = @MOId;

        INSERT INTO dbo.MOQtyExtendAllowLog (
            MOId, MOName,
            OldQtyExtendAllow, NewQtyExtendAllow,
            OperateUserId, OperateUserName, ResourceName, CreateDate
        )
        VALUES (
            @MOId, ISNULL(@MOName, N''),
            @OldExtend, @MOQtyExtendAllow,
            ISNULL(@I_OrBitUserId, N''), ISNULL(@I_OrBitUserName, N''), ISNULL(@I_ResourceName, N''), GETDATE()
        );

        COMMIT TRANSACTION;

        SET @I_ReturnMessage = N'ServerMessage:延号允许数量已更新：'
            + CAST(@OldExtend AS NVARCHAR(30)) + N' → '
            + CAST(@MOQtyExtendAllow AS NVARCHAR(30));

        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @I_ReturnMessage = N'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH;
END;
