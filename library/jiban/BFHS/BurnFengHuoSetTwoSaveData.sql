
-- =============================================
-- 对象:  BurnFengHuoSetTwoSaveData
-- 说明:  烽火老化时间配置Two - 保存数据
--        不需要传参 CreateDate、@CreateUserId，系统内部自动赋值
-- 日期:  2026-07-10
-- =============================================
CREATE PROCEDURE [dbo].[BurnFengHuoSetTwoSaveData]
    @I_ReturnMessage      NVARCHAR(MAX) = '' OUTPUT,
    @I_IsNewRow           BIT = 0 OUTPUT,
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT,
    @I_LanguageId         CHAR(1) = '1',
    @I_PlugInCommand      VARCHAR(5) = '',
    @I_OrBitUserId        CHAR(12) = '',
    @I_OrBitUserName      NVARCHAR(100) = '',
    @I_ResourceId         CHAR(12) = '',
    @I_ResourceName       NVARCHAR(100) = '',
    @I_PKId               CHAR(12) = '',
    @I_SourcePKId         CHAR(12) = '',
    @I_ParentPKId         CHAR(12) = '',
    @I_Parameter          NVARCHAR(100) = '',

    -- 业务字段参数（不传入 CreateDate、CreateUserId）
    @ControlType   NVARCHAR(20) = '',   -- 控制类型
    @ControlValue  NVARCHAR(50) = '',   -- 控制值
    @BurnTimeSet   DECIMAL(18, 2) = 0,  -- 老化时间设定
    @IsEnabled     BIT = 1,             -- 是否启用
    @Remark        NVARCHAR(200) = ''   -- 备注
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        -- 初始化
        SET @I_ReturnMessage = '';
        SET @I_IsNewRow = 0;
        SET @I_ExceptionFieldName = '';

        -- 检查主键
        IF LTRIM(@I_PKId) = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:No PKId applied';
            RETURN -1;
        END;

        -- 判断新增还是更新
        IF NOT EXISTS (SELECT 1 FROM dbo.BurnFengHuoSetTwo WHERE BurnFengHuoSetTwoId = @I_PKId)
        BEGIN
            -- 新增（CreateDate、CreateUserId 自动赋值）
            INSERT INTO dbo.BurnFengHuoSetTwo (
                BurnFengHuoSetTwoId, ControlType, ControlValue, BurnTimeSet,
                IsEnabled, Remark, CreateDate, CreateUserId
            )
            VALUES (
                @I_PKId, @ControlType, @ControlValue, @BurnTimeSet,
                @IsEnabled, @Remark, GETDATE(), @I_OrBitUserId
            );

            SET @I_IsNewRow = 1;
        END
        ELSE
        BEGIN
            -- 更新（不修改 CreateDate、CreateUserId）
            UPDATE dbo.BurnFengHuoSetTwo SET
                ControlType = @ControlType,
                ControlValue = @ControlValue,
                BurnTimeSet = @BurnTimeSet,
                IsEnabled = @IsEnabled,
                Remark = @Remark
            WHERE BurnFengHuoSetTwoId = @I_PKId;
        END;

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        INSERT INTO dbo.SqlProcedureIssueLog (
            ProcName, IssueType, StepCode, Message,
            ErrNumber, ErrLine, ErrMessage, OrBitUserId
        )
        VALUES (
            N'BurnFengHuoSetTwoSaveData', N'SQL_EXCEPTION', N'CATCH',
            N'BurnFengHuoSetTwo保存异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );

        SET @I_ReturnMessage = 'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;


