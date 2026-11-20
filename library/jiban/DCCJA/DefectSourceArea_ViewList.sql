
-- =============================================
-- Author:		<LZH>
-- Create date: <2024.10.15>
-- Description:	<获取不良来源>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[DefectSourceArea_ViewList]
    @QueryParameter NVARCHAR(100) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	
	SELECT 'SMT' AS DefectSourceArea
	UNION ALL
	SELECT 'DIP' AS DefectSourceArea
	UNION ALL
	SELECT '总三' AS DefectSourceArea
	UNION ALL
	SELECT '总四' AS DefectSourceArea
	UNION ALL
	SELECT '总五' AS DefectSourceArea
	UNION ALL
	SELECT '总六' AS DefectSourceArea
	UNION ALL
	SELECT '其他' AS DefectSourceArea
    
    RETURN 0;

END;
