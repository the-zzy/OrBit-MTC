
-- =============================================
-- Author:		<OrBit Team benson>
-- Create date: <2016.10.17>
-- Description:	<根据散件订单获取工单号>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[MOByKDOrder_ViewListPK] 
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId char(12)='',			--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12)='',				--主键ID
@I_ParentPKId char(12)='',			--父元对象主键ID
@QueryParameter nvarchar(100)='' 
--以上个变量为系统服务固定接口参数，必须在每一个ViewListEx过程中实现.>
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	declare @OrderName nvarchar(50)
	set @OrderName=''
    
	select @OrderName=OrderName from KDOrderInfo where KDOrderInfoId=@I_ParentPKId

	select 
		MO.MOId,
		[dbo].[RemoveZero](MO.MOName) as MOName,
		[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,
		Convert(float,MO.MOQtyRequired) as MOQtyRequired,
		Product.ProductDescription
	from MO 
	left join Product on Product.ProductId=MO.ProductId
	left join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where MO.SOName=substring(@OrderName,3,10)

	return 0
END


