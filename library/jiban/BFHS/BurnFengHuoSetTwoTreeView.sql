


-- =============================================
-- 对象:  BurnFengHuoSetTwoTreeView
-- 说明:  烽火老化时间配置Two - 树视图
-- 日期:  2026-07-10
-- =============================================
CREATE PROCEDURE [dbo].[BurnFengHuoSetTwoTreeView]
    @I_ReturnMessage      NVARCHAR(MAX) = '' OUTPUT,
    @I_LanguageId         CHAR(1) = '1',
    @I_PlugInCommand      VARCHAR(5) = '',
    @I_FiltCondition      NVARCHAR(MAX) = '',
    @I_OrBitUserId        CHAR(12) = '',
    @I_OrBitUserName      NVARCHAR(100) = '',
    @I_ResourceId         CHAR(12) = '',
    @I_ResourceName       NVARCHAR(100) = '',
    @I_PKId               CHAR(12) = '',
    @I_ParentPKId         CHAR(12) = '',
    @I_Parameter          NVARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    -- 当 SaveData 执行完成后刷新单行时执行
    IF @I_PKId <> ''
    BEGIN
        SELECT
            BurnFengHuoSetTwoId,
            ControlType,
            ControlValue,
            BurnTimeSet,
            IsEnabled,
            Remark
        FROM dbo.BurnFengHuoSetTwo WITH(NOLOCK)
        WHERE BurnFengHuoSetTwoId = @I_PKId;
        RETURN 0;
    END;

    -- 返回所有数据
    SELECT
        BurnFengHuoSetTwoId,
        ControlType,
        ControlValue,
        BurnTimeSet,
        IsEnabled,
        Remark
    FROM dbo.BurnFengHuoSetTwo WITH(NOLOCK)
    ORDER BY ControlType, ControlValue;

    RETURN 0;
END;


