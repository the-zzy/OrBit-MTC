
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.10.12>
-- Description:	<获取TV工单列表>
-- Rev:1.00
-- =============================================
CREATE PROCEDURE [dbo].[MOByAssyTV_ViewListEx] 
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@QueryParameter nvarchar(100)=''	--值列表级联时使用
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @WorkcenterName nvarchar(50)
	declare @UserDescription nvarchar(50)

	set @WorkcenterName=''
	set @UserDescription=''

	select 
		@WorkcenterName=WorkcenterName,
		@UserDescription=SysUser.UserDescription 
	from SysUser 
	inner join Workcenter on Workcenter.WorkcenterId=SysUser.WorkcenterId
	where SysUser.UserId=@I_OrBitUserId
     
	set @WorkcenterName=@WorkcenterName+' '+@UserDescription

	if exists(select 1 from OrderFieldSetting where OrderName=@QueryParameter and ISNULL(MOId,'')<>'')
	begin
		select 
			MO.MOId,
			[dbo].[RemoveZero](MO.MOName) as MOName,
			Product.ProductId,
			[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,
			Convert(int,MO.MOQtyRequired) as MOQtyRequired,
			@WorkcenterName as WorkcenterName
		from MO
		inner join Product on Product.ProductId=MO.ProductId
		inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
		inner join OrderFieldSetting on OrderFieldSetting.MOId=MO.MOId and OrderFieldSetting.OrderName=@QueryParameter
		where ProductTypeId='URC1000000PZ'
		order by MO.MOName

		return 0
	end

	select 
		MO.MOId,
		[dbo].[RemoveZero](MO.MOName) as MOName,
		Product.ProductId,
		[dbo].[RemoveZero](ProductRoot.ProductName) as ProductName,
		Convert(int,MO.MOQtyRequired) as MOQtyRequired,
		@WorkcenterName as WorkcenterName
	from MO
	inner join Product on Product.ProductId=MO.ProductId
	inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where MO.SOName in (select distinct SOName from OrderFieldSetting where OrderFieldSetting.OrderName=@QueryParameter)
	and  ProductTypeId='URC1000000PZ'
	order by MO.MOName



	return 0

END


