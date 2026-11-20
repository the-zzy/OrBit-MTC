
-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2016.05.19>
-- Description:	<获取面别 列表>
-- Rev:1.00
-- =============================================
Create PROCEDURE [dbo].[Side_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT  ParameterValue AS Side FROM dbo.SysParameter
	where ParameterName='[SMTMount Side]'
	order by ParameterValue

	return 0

END




