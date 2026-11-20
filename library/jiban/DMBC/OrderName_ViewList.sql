
-- =============================================
-- Author:		<OrBit Phoenix>
-- Create date: <2016.06.14>
-- Description:	<获取订单号>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[OrderName_ViewList] 
@QueryParameter nvarchar(100)=''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	select distinct 
		a.OrderFieldSettingId,
		a.OrderName,
		a.productName,
		a.OrderType,
		b.ProductDescription
	from OrderFieldSetting a
	    INNER JOIN dbo.Product b ON b.ProductId = a.ProductId
	where IsClose=0
	order by a.OrderName

	return 0

END





