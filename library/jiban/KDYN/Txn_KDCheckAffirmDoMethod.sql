
-- =============================================
-- Author:		<OrBit benson>
-- Create Date: <2017.01.07>
-- Description:	散件物料检验确认 OQC/OQA
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_KDCheckAffirmDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId	char(12)='',		--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(500)=''		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
			declare @return_value int
	set @return_value=-1

	--检查元对象方法用户授权
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

	declare @KDOrderInfoId char(12)
	declare @OrderName nvarchar(50)
	declare @KDOrderItemId char(12)
	declare @ModuleName nvarchar(50)

	set @KDOrderInfoId=''
	set @OrderName=''
	set @KDOrderItemId=''
	set @ModuleName=''

	if ISNULL(@I_PKid,'')='' or ISNULL(@I_ParentPKId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择有效行项.'
		return -1
	end

	--获取订单信息
	select 
		@KDOrderInfoId=KDOrderInfoId,
		@OrderName=OrderName
	from KDOrderInfo 
	where KDOrderInfoId=@I_ParentPKId

	if LEN(@I_Parameter)-5>LEN(REPLACE(@I_Parameter,';',''))
	begin
		set @I_ReturnMessage='ServerMessage:每次只能最多选中 5 个组件，请检查!'
		return -1
	end

	--游标写入数据
	DECLARE cursor1 CURSOR FOR  
	SELECT parameter_Value FROM dbo.ConvertParameterToTable(@I_Parameter,';')
	order by parameter_Value
	OPEN cursor1
	fetch next from cursor1 
	into @KDOrderItemId
	while @@FETCH_STATUS = 0 
	begin

		if not exists(select 1 from KDOrderItem where KDOrderItemId=@KDOrderItemId)
		begin
			set @I_ReturnMessage='ServerMessage:订单行物料不存在!'
			return -1
		end

		set @ModuleName=''

		--获取物料行
		select 
			@ModuleName=ModuleName
		from KDOrderItem 
		where KDOrderItemId=@KDOrderItemId

		if ISNULL(@I_Sender,'')='OQCOK'
		begin
			if not exists(select 1 from KDOrderItem where ModuleName=@ModuleName and OQCAffirmResult='0')
			begin
				set @I_ReturnMessage='ServerMessage:订单行物料已执行 OQC 确认，不允许重复确认!'
				return -1
			end

			if exists(select 1 from KDOrderItem where ModuleName=@ModuleName)
			begin
				update KDOrderItem set 
					OQCAffirmResult='1',
					OQCAffirmDate=GETDATE(),
					OQCAffirmUserId=@I_OrBitUserId
				where ModuleName=@ModuleName
			end
		end

		if ISNULL(@I_Sender,'')='OQCNG'
		begin
			if not exists(select 1 from KDOrderItem where ModuleName=@ModuleName and OQCAffirmResult='0')
			begin
				set @I_ReturnMessage='ServerMessage:订单行物料已执行 OQC 确认，不允许重复确认!'
				return -1
			end

			if exists(select 1 from KDOrderItem where ModuleName=@ModuleName)
			begin
				update KDOrderItem set 
					OQCAffirmResult='2',
					OQCAffirmDate=GETDATE(),
					OQCAffirmUserId=@I_OrBitUserId
				where ModuleName=@ModuleName
			end
		end

		if ISNULL(@I_Sender,'')='OQCRepeal'
		begin
			if exists(select 1 from KDOrderItem where ModuleName=@ModuleName)
			begin
				update KDOrderItem set 
					OQCAffirmResult='0',
					OQCAffirmDate=null,
					OQCAffirmUserId=''
				where ModuleName=@ModuleName
			end
		end

		if ISNULL(@I_Sender,'')='OQAOK'
		begin
			if not exists(select 1 from KDOrderItem where ModuleName=@ModuleName and OQAAffirmResult='0')
			begin
				set @I_ReturnMessage='ServerMessage:订单行物料已执行 OQA 确认，不允许重复确认!'
				return -1
			end

			if exists(select 1 from KDOrderItem where ModuleName=@ModuleName)
			begin
				update KDOrderItem set 
					OQAAffirmResult='1',
					OQAAffirmDate=GETDATE(),
					OQAAffirmUserId=@I_OrBitUserId
				where ModuleName=@ModuleName
			end
		end

		if ISNULL(@I_Sender,'')='OQANG'
		begin
			if not exists(select 1 from KDOrderItem where ModuleName=@ModuleName and OQAAffirmResult='0')
			begin
				set @I_ReturnMessage='ServerMessage:订单行物料已执行 OQA 确认，不允许重复确认!'
				return -1
			end

			if exists(select 1 from KDOrderItem where ModuleName=@ModuleName)
			begin
				update KDOrderItem set 
					OQAAffirmResult='2',
					OQAAffirmDate=GETDATE(),
					OQAAffirmUserId=@I_OrBitUserId
				where ModuleName=@ModuleName
			end
		end

		if ISNULL(@I_Sender,'')='OQARepeal'
		begin
			if exists(select 1 from KDOrderItem where ModuleName=@ModuleName and ModuleName=@ModuleName)
			begin
				update KDOrderItem set 
					OQAAffirmResult='0',
					OQAAffirmDate=null,
					OQAAffirmUserId=''
				where ModuleName=@ModuleName
			end
		end

		fetch next from cursor1 
		into @KDOrderItemId
	end
	CLOSE cursor1
	DEALLOCATE cursor1 


	if ISNULL(@I_Sender,'')='OQCOK'
		set @I_ReturnMessage='ServerMessage:组件 ['+@ModuleName+'] OQC 确认合格.'

	if ISNULL(@I_Sender,'')='OQCNG'
		set @I_ReturnMessage='ServerMessage:组件 ['+@ModuleName+'] OQC 确认不合格.'
	
	if ISNULL(@I_Sender,'')='OQCRepeal'
		set @I_ReturnMessage='ServerMessage:组件 ['+@ModuleName+'] OQC 确认撤销.'

	if ISNULL(@I_Sender,'')='OQAOK'
		set @I_ReturnMessage='ServerMessage:组件 ['+@ModuleName+'] OQA 确认合格.'

	if ISNULL(@I_Sender,'')='OQANG'
		set @I_ReturnMessage='ServerMessage:组件 ['+@ModuleName+'] OQA 确认不合格.'

	if ISNULL(@I_Sender,'')='OQARepeal'
		set @I_ReturnMessage='ServerMessage:组件 ['+@ModuleName+'] OQA 确认撤销.'

	return 0
END
 









