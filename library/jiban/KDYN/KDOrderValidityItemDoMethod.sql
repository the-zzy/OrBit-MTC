
-- =============================================
-- Author:		<OrBit Team Phoenix>
-- Create date: <2017.05.27>
-- Description:	<散件订单明细有效行项>
-- Rev: 10.00
--=============================================
CREATE PROCEDURE  [dbo].[KDOrderValidityItemDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKId char(12) = '',				--主键
@I_SourcePKId char(12)='',			--执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(Max)=''		--插件参数	

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON; 
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	declare @return_value int
	set @return_value=-1

	----检查元对象方法用户授权
	exec @return_value=[dbo].[MetadataPermissionCheckDoMethod]
		@I_ReturnMessage=@I_ReturnMessage output,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_Sender=@I_Sender

	if @return_value=-1
	begin
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	declare @KDOrderItemId char(12)
	declare @KDOrderInfoId char(12)
	declare @OldProductId char(12)=''	
	declare	@OldModuleName nvarchar(50)=''

	set @KDOrderItemId=''
	set @KDOrderInfoId=''
	
	if ISNULL(@I_PKId,'')='' or ISNULL(@I_ParentPKId,'')='' or ISNULL(@I_Parameter,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择有效行项!'
		return -1
	end

	-----已经生产箱号，不允许修改--
	select @OldProductId=ProductId,
			@OldModuleName=ModuleName
			from KDOrderItem where KDOrderItemId=@I_PKId

	if exists(select 1 from KDBoxItem where KDOrderInfoId=@I_ParentPKId and ProductId=@OldProductId and ModuleName=@OldModuleName and IsCancel=0 )
	begin
		set @I_ReturnMessage='ServerMessage:已经生成箱号，不允许操作!'
		return -1
	end

	declare @tb table
	(KDOrderItemId char(12))
	

	set @KDOrderItemId=@I_PKId
	set @KDOrderInfoId=@I_ParentPKId

	insert into @tb
	select parameter_Value from dbo.ConvertParameterToTable(@I_Parameter,';')

	--如果已被忽略，则取消忽略
	if exists(select top 1 KDOrderItemId from KDOrderItem where KDOrderInfoId=@KDOrderInfoId and KDOrderItemId in(select KDOrderItemId from @tb) and IsValidity=1 order by KDOrderItemId )
	begin
		update KDOrderItem set IsValidity=0 where KDOrderInfoId=@KDOrderInfoId and KDOrderItemId in(select KDOrderItemId from @tb)

		set @I_ReturnMessage='ServerMessage:失效成功!'
		return 0
	end

	--更新状态为已忽略
	if exists(select 1 from KDOrderItem where KDOrderInfoId=@KDOrderInfoId and KDOrderItemId in(select KDOrderItemId from @tb))
	begin
		update KDOrderItem set IsValidity=1 where KDOrderInfoId=@KDOrderInfoId and KDOrderItemId in(select KDOrderItemId from @tb)

		set @I_ReturnMessage='ServerMessage:订单行项已经生效!'

		return 0
	end
	
END


















