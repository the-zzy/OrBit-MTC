
-- =============================================
-- 对象:  BurnFengHuoSetTwoDeleteData
-- 说明:  烽火老化时间配置Two - 删除数据（物理删除）
-- 日期:  2026-07-10
-- =============================================
CREATE PROCEDURE [dbo].[BurnFengHuoSetTwoDeleteData]
    @I_ReturnMessage      NVARCHAR(MAX) = '' OUTPUT,
    @I_LanguageId         CHAR(1) = '1',
    @I_PlugInCommand      VARCHAR(5) = '',
    @I_OrBitUserId        CHAR(12) = '',
    @I_OrBitUserName      NVARCHAR(100) = '',
    @I_ResourceId         CHAR(12) = '',
    @I_ResourceName       NVARCHAR(100) = '',
    @I_PKId               CHAR(12) = '',
    @I_ParentPKId         CHAR(12) = '',
    @I_Parameter          NVARCHAR(100) = ''
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

        -- 初始化
        SET @I_ReturnMessage = '';

        -- 检查主键
        IF LTRIM(@I_PKId) = ''
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:No PKId applied';
            RETURN -1;
        END;

        -- 检查记录是否存在
        IF NOT EXISTS (SELECT 1 FROM dbo.BurnFengHuoSetTwo WHERE BurnFengHuoSetTwoId = @I_PKId)
        BEGIN
            SET @I_ReturnMessage = 'ServerMessage:记录不存在';
            RETURN -1;
        END;

        -- 物理删除（配置表无 IsCancel 字段）
        DELETE FROM dbo.BurnFengHuoSetTwo
        WHERE BurnFengHuoSetTwoId = @I_PKId;

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
            N'BurnFengHuoSetTwoDeleteData', N'SQL_EXCEPTION', N'CATCH',
            N'BurnFengHuoSetTwo删除异常', @ErrNum, @ErrLine, @ErrMsg, @I_OrBitUserId
        );

        SET @I_ReturnMessage = 'ServerMessage:' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;


