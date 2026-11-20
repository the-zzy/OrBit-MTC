
-- =============================================
-- Author:		<OrBit Team Alick>
-- Create date: <2020.06.02>
-- Description:	<为元字段获取PickingLis清单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[StockList_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT 
		StockListId, 
		StockListName
	FROM StockList
	WHERE  StockList.StockListStates IN('20','30')
	ORDER BY CreateDate DESC
	return 0
END

