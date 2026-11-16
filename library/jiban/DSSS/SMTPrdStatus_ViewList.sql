
-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2015.10.28>
-- Description:	<获取 SMT 料站表面别>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[SMTPrdStatus_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT '待A面' AS SoNtype
	UNION ALL
    SELECT '待AI' AS SoNtype
	UNION ALL
	SELECT '待DIP' AS SoNtype
	UNION ALL
	SELECT '维修/清 尾' AS SoNtype
	UNION all
	SELECT '待测试' AS SoNtype

	return 0

END



