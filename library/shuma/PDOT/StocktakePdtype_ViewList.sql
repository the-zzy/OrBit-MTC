-- =============================================
-- Author:		<OBit Team  H.R.>
-- Create date: <2008.8.8>
-- Description:	<获取_SampleProject清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[StocktakePdtype_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT '自盘' AS 'Pdtype'
	UNION ALL 
	SELECT '复盘' AS 'Pdtype'

	RETURN 0;
	 
END


