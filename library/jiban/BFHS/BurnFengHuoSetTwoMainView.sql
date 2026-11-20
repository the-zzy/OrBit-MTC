
-- =============================================
-- 对象:  BurnFengHuoSetTwoMainView
-- 说明:  烽火老化时间配置Two - 主视图查询
-- 日期:  2026-07-10
-- =============================================
CREATE PROCEDURE [dbo].[BurnFengHuoSetTwoMainView]
    @I_PKId CHAR(12) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

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


