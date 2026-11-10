-- =============================================
-- Author:		<OrBit Team>
-- Create date: <2009.4.20>
-- Description:	<获取Customer的主视图>
-- =============================================
CREATE PROCEDURE [dbo].[CustomerMainView] 
@I_PKId char(12)=''					--主键>
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	SELECT 
		Customer.CustomerId,
		Customer.CustomerName,
		Customer.CustomerAbbr,
		Customer.CustomerDescription,
		Customer.DeleteFlag,
		Customer.ERPDate,MaterialReturn
	FROM   Customer
	WHERE  (Customer.CustomerId = @I_PKId)
END
