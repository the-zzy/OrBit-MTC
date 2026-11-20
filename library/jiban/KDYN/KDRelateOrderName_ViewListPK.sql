-- =============================================
-- Author:		<gc3033-11-27>
-- Create date: <2017>
-- Description:	<SKD订单关联大货预置数据订单>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[KDRelateOrderName_ViewListPK] 
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12)='',				--主键ID
@I_ParentPKId char(12)='',			--父元对象主键ID
@QueryParameter nvarchar(100)=''
--以上8个变量为系统服务固定接口参数，必须在每一个ViewWindow过程中实现.>
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @SOName nvarchar(50)=''
	select @SOName=SOName from KDOrderInfo where KDOrderInfoId=@I_ParentPKId
	;
	with temp as(
	select OrderName,ProductId from OrderFieldSetting a
	 where SOName=@SOName and OrderType!='DIP'
	 )
	 select a.OrderName,c.ProductName,b.ProductDescription from temp a
	 inner join Product b on a.ProductId=b.ProductId
	 inner join ProductRoot c on b.ProductRootId=c.ProductRootId

	return 0


END


