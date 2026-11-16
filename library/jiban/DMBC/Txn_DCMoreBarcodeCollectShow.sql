
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016.05.03>
-- Description:	<多码合一采集扫描-显示>
-- =============================================
CREATE PROCEDURE [dbo].[Txn_DCMoreBarcodeCollectShow] 
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
@I_Parameter nvarchar(100)='', 		--插件参数	

@OrderName nvarchar(50)='',         --订单号
@MOId char(12)='',
@Operator nvarchar(50)='',          --操作员
@LotSN nvarchar(50)='',             --产品批号
@CollectStr nvarchar(max)=''

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int
	declare @TxnCode varchar(10)
	declare @Date datetime
	declare @DataChainId char(12)
	declare @MESTxnObjectName nvarchar(50)  --事务对象名称
	declare @ProductId char(12)
	declare @ProductName nvarchar(50)
	declare @WorkcenterId char(12)
	declare @WorkcenterName nvarchar(50)
	declare @LotId char(12)
	declare @LotProductId char(12)
	declare @LotWorkflowId char(12)
	declare @LotSpecificationId char(12)
	declare @LotSpecificationName nvarchar(50)
	declare @LotStatus varchar(10)
	declare @LotWorkflowStepId char(12)
	declare @CollectCount int        --采集项的项数
	declare @ScanCount int            --扫描的采集项个数
	declare @NextItemName nvarchar(50)
	declare @WorkflowId char(12)
	declare @CollectSettingId char(12)
	declare @ItemName nvarchar(50)
	declare @Sequence int
	declare @CollectProductId char(12)
	declare @DataChainAssemblyId char(12)
	declare @SOName nvarchar(50)
	declare @OrderFieldSettingId char(12)
	declare @MOItemLotId char(12)
	declare @MOItemId char(12)
	declare @MOName nvarchar(50)
	declare @FinishQty float
	declare @sql nvarchar(max)
	declare @SNItem nvarchar(50)
	declare @SNValue nvarchar(50)
	declare @OrderSetItemId char(12)

	set @return_value=-1
	set @I_ExceptionFieldName='LotSN'	
	set @TxnCode='DC'
	set @MESTxnObjectName='DC MoreBarcodeCollect'
	set @Date=GETDATE()
	set @WorkcenterId=''
	set @WorkcenterName=''
	set @ProductId=''
	set @ProductName=''
	set @LotId=''
	set @LotProductId=''
	set @LotSpecificationId=''
	set @LotSpecificationName=''
	set @LotStatus=''
	set @LotWorkflowStepId=''
	set @CollectCount=0
	set @ScanCount=0
	set @NextItemName=''
	set @WorkflowId=''
	set @CollectSettingId=''
	set @ItemName=''
	set @Sequence=0
	set @CollectProductId=''
	set @DataChainAssemblyId=''
	set @LotWorkflowId=''
	set @SOName=''
	set @OrderFieldSettingId=''
	set @MOItemLotId=''
	set @MOItemId=''
	set @MOName=''
	set @FinishQty=0
	set @sql=''
	set @SNItem=''
	set @SNValue=''
	set @OrderSetItemId=''

	--转换大写
	set @LotSN=UPPER(RTRIM(LTRIM(@LotSN)))
	set @Operator=UPPER(RTRIM(LTRIM(@Operator)))

	--检查资源是否已维护
	if ISNULL(@I_ResourceId,'')=''
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue ,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:资源 ['+@I_ResourceName+'] 未在 MES 系统维护，请检查!'
		return -1
	end

	if ISNULL(@OrderName,'')=''
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue ,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:请选择订单号!'
		set @I_ExceptionFieldName='OrderName'
		return -1
	end

	--检查是否为空
	if ISNULL(@MOId,'')=''
	begin	
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue ,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:请选择工单号!'
		set @I_ExceptionFieldName='MOName'
		return -1
	end

	--检查工号是否存在
	if not exists(select 1 from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as Operator,'' as LotSN,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:操作员工号 ['+@Operator+'] 无效，请检查!'
		set @I_ExceptionFieldName='Operator'
		return -1
	end

	if not exists(select top 1 MOId from MO where MOId=@MOId)
	begin	
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:工单 ['+@MOName+'] 不存在!'
		return -1	
	end

	--获取订单信息
	select 
		@OrderFieldSettingId=OrderFieldSettingId
	from OrderFieldSetting 
	where OrderName=@OrderName
	
	--获取工单数据
	select 
		@MOName=MO.MOName,
		@ProductId=MO.ProductId,
		@WorkflowId=MO.WorkflowId,
		@ProductName=[dbo].[RemoveZero](ProductRoot.ProductName)
	from MO 
	inner join Product on Product.ProductId=MO.ProductId
	inner join ProductRoot on ProductRoot.ProductRootId=Product.ProductRootId
	where MOId=@MOId

	select 
		@MOItemId=MOItem.MOItemId 
	from MOItem 
	where MOId=@MOId and ProductId=@ProductId

	if ISNULL(@WorkflowId,'')=''
	begin
		select 
			@WorkflowId=ISNULL(Product.WorkflowId,'')
		from Product 
		where Product.ProductId=@ProductId
	end	

	if ISNULL(@WorkflowId,'')=''
	begin
		--返回界面
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:工单 ['+@MOName+'] 未维护工作流，不允许操作!'
		return -1 
	end

	--检查是否已导入该订单的条码信息
	exec @return_value=[dbo].[Txn_LotStartCheckDoMethod] 
		@I_ReturnMessage=@I_ReturnMessage output,
		@OrderSetItemId=@OrderSetItemId output,
		@OrderName=@OrderName,
		@MOId=@MOId,
		@LotSN=@LotSN

	if @return_value=-1
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	--LotSN 是否有效
	if not exists(select 1 from Lot where LotSN=@LotSN)
	begin
		--启动工单批号
		set @return_value=-1

		EXEC @return_value = [dbo].[TxnBase_LotStart]
			@I_ReturnMessage = @I_ReturnMessage OUTPUT,
			@I_PlugInCommand = @I_PlugInCommand ,
			@I_OrBitUserId = @I_OrBitUserId,
			@I_ResourceId = @I_ResourceId,
			@LotId = @LotId OUTPUT,
			@LotSN = @LotSN,
			@ProductId =@ProductId,
			@Qty = 1,
			@WorkflowId = @WorkflowId,
			@OrderName=@OrderName,
			@MOId=@MOId

		if @return_value=-1
		begin
			select '' as ID,'' as CollectName,'' as CollectSN

			select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
			set @I_ReturnMessage=@I_ReturnMessage
			return -1
		end

		--更新 OrderSetItem 表 LotId
		update OrderSetItem set LotId=@LotId where OrderSetItemId=@OrderSetItemId

		if not exists(select 1 from MOItemLot where MOId=@MOId and LotSN=@LotSN)
		begin
			--写入 MOItemLot 表
			exec SysGetObjectPKId '','MOItemLot',@MOItemLotId output
			insert into MOItemLot(
					MOItemLotId,
					MOId,
					MOItemId,
					LotId,
					LotSN,
					LotQty,
					ProductId)
				values(
					@MOItemLotId,
					@MOId,
					@MOItemId,
					@LotId,
					@LotSN,
					1,
					@ProductId
					)
		end

		--更新数据为已使用状态
		update OrderSetItem set IsUsed=1 where OrderSetItemId=@OrderSetItemId
	end

	--获取 Lot 信息
	select 
		@LotId=LotId,
		@LotStatus=LotStatus,
		@LotProductId=ProductId,
		@LotWorkflowId=WorkflowId,
		@LotSpecificationId=SpecificationId,
		@LotWorkflowStepId=WorkflowStepId
	from  Lot 
	where LotSN=@LotSN

	if ISNULL(@LotStatus,'')<>'1'
	begin
		--返回界面
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品批号 ['+@LotSN+'] 状态不可用!'
		return -1
	end

	--检查资源或者用户是否允许操作此规程
	exec @return_value=dbo.[SysCheckSpecification]
		@I_ReturnMessage=@I_ReturnMessage output,
		@WorkcenterId=@WorkcenterId output,
		@LotId=@LotId,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_ResourceId=@I_ResourceId,
		@I_ResourceName=@I_ResourceName,
		@SpecificationId=@LotSpecificationId,
		@MESTxnObjectName=@MESTxnObjectName

	if @return_value=-1
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	--线别不能为空
	if ISNULL(@WorkcenterId,'')=''
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:用户 ['+@I_OrBitUserName+'] 或者资源 ['+@I_ResourceName+'] 未绑定线别，不允许操作!'
		return -1
	end

	select @WorkcenterName=WorkcenterName from Workcenter where WorkcenterId=@WorkcenterId

	--获取规程信息
	select @LotSpecificationName=SpecificationRoot.SpecificationName 
	from Specification
	inner join SpecificationRoot on SpecificationRoot.SpecificationRootId=Specification.SpecificationRootId
	where Specification.SpecificationId=@LotSpecificationId

	--检查品号是否已维护采集项信息
	if not exists(select 1 from Product_CollectSetting where ProductId=@LotProductId and SpecificationId=@LotSpecificationId)
	begin
		select '' as ID,'' as CollectName,'' as CollectStr,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品 ['+@ProductName+'] 未维护规程 ['+@LotSpecificationName+'] 的采集项，请检查!'
		return -1
	end

	--如果不需要维护采集项
	if exists(select 1 from Product_CollectSetting 
					inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
					where Product_CollectSetting.ProductId=@LotProductId and SpecificationId=@LotSpecificationId and CollectItem.CollectItemName='NULL')
	begin
		--是否装配节点，是，则需要进行扣料倒冲
		if exists(select 1 from Specification where SpecificationId=@LotSpecificationId and IsAssemblyStep=1)
		begin
			EXEC @return_value=[dbo].[OtherBackflushDoMethod] 
				@I_ReturnMessage=@I_ReturnMessage output,
				@I_ResourceId=@I_ResourceId,
				@I_OrBitUserId=@I_OrBitUserId,
				@MOId=@MOId,
				@ProductId=@LotProductId,
				@WorkcenterId=@WorkcenterId,
				@LotSN=@LotSN,
				@MakeupNumber=1
		
			--倒冲扣数不成功，返回
			if @return_value =-1
			begin
				--如果扣数不成功，则删除中间表采集信息
				set @CollectStr=''

				select '' as ID,'' as CollectName,'' as CollectSN

				select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
				set @I_ReturnMessage=@I_ReturnMessage	
				return -1
			end	
		end

		--统计在制品
		EXEC [dbo].[DataChainWIPDoMethod]
			@I_OrBitUserId=@I_OrBitUserId,
			@I_ResourceId=@I_ResourceId,
			@MOId = @MOId,
			@LotId = @LotId,
			@WorkcenterId = @WorkcenterId,
			@MoveResult = 'P',
			@FinishQty=@FinishQty output

		--传送 LotSN 到工作流下一节点
		EXEC [dbo].[TxnBase_LotMove] 
			@I_ReturnMessage=@I_ReturnMessage OUTPUT,
			@I_OrBitUserId=@I_OrBitUserId,
			@I_ResourceId=@I_ResourceId,
			@LotSN=@LotSN,
			@LotInDate=@Date

		--试投物料
		EXEC [dbo].[TrialProduceMaterialData]
			@I_ReturnMessage = @I_ReturnMessage OUTPUT,
			@I_OrBitUserId = @I_OrBitUserId,
			@I_ResourceId = @I_ResourceId,
			@MOId = @MOId,
			@LotId = @LotId

				
		--返回网格数据
		select '' as ID,'' as CollectName,'' as CollectSN
		select '' as LotSN,'' as ItemValue,@FinishQty as FinishQty,'' as CollectStr,'ok.png' as WarnImage
		
		set @I_ReturnMessage=@I_ReturnMessage

		return 0
	end
	
	--检查采集项是否都已维护检查规则
	exec @return_value=[dbo].[Txn_CollectSettingRuleCheck]
		@I_ReturnMessage=@I_ReturnMessage output,
		@ProductId=@ProductId,
		@SpecificationId=@LotSpecificationId

	if @return_value=-1
	begin
		select '' as ID,'' as CollectName,'' as CollectSN
		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end
	
	--清空中间表数据
	set @CollectStr=''

	--获取当前站第一个采集项
	select top 1 @NextItemName=CollectItem.CollectItemName 
	from Product_CollectSetting 
	inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
	where ProductId=@ProductId and SpecificationId=@LotSpecificationId
	order by Sequence

	--返回网格数据
	select 
		Product_CollectSetting.Sequence,
		CollectItem.CollectItemName,
		'' AS CollectSN 
	from Product_CollectSetting
	inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
	where Product_CollectSetting.ProductId=@ProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId
	order by Product_CollectSetting.Sequence	

	select @WorkcenterName as WorkcenterName,@NextItemName as NextItemName,'' as ItemValue,'' as LotStr,'' as CollectStr,'right.png' as WarnImage

	set @I_ReturnMessage='ServerMessage:请扫描 ['+ISNULL(@NextItemName,'')+']!'
	set @I_ExceptionFieldName='ItemValue'

	return 0
	
END



