
-- =============================================
-- Author:		<OrBit benson>
-- Create date: <2016-05-03>
-- Description:	<多码合一采集扫描>
-- =============================================
CREATE PROCEDURE [dbo].[Txn_DCMoreBarcodeCollect] 
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
@MOId char(12)='',                  --工单ID
@Operator nvarchar(50)='',          --操作员
@LotSN nvarchar(50)='',             --产品条码
@ItemValue nvarchar(50)='',         --采集项内容       
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
	declare @WorkcenterName nvarchar(50)
	declare @LotSpecificationName nvarchar(50)
	declare @LotId char(12)
	declare @LotStatus char(1)
	declare @LotQty float
	declare @LotProductId char(12)
	declare @WorkcenterId char(12)
	declare @LotWorkflowId char(12)
	declare @LotWorkflowStepId char(12)
	declare @LotSpecificationId char(12)
	declare @ItemName nvarchar(50)
	declare @CollectSettingId char(12)
	declare @DataChainAssemblyId char(12)
	declare @CollectSN nvarchar(50)
	declare @ScanTempCount int
	declare @CollectCount int
	declare @Sequence int                   --采集项的顺序
	declare @NextItemName nvarchar(50)
	declare @ScanQty int                   --资源扫描数
	declare @IsAssemblyStep bit            --是否装配节点
	declare @MESTxnObjectName nvarchar(50)  --事务名称
	declare @CollectItemId char(12)
	declare @OrderFieldSettingId char(12)
	declare @sql nvarchar(max)
	declare @SNItem nvarchar(50)
	declare @SNValue nvarchar(50)
	declare @OrderSetItemId char(12)
	declare @FinishQty float
	declare @i int
	declare @TempStr nvarchar(50)
	declare @TempItemName nvarchar(50)
	declare @TempItemValue nvarchar(50)
	declare @index int

	set @return_value=-1
	set @I_ExceptionFieldName='ItemValue'
	set @TxnCode='DC'
	set @Date=GETDATE() 
	set @MESTxnObjectName='DC MoreBarcodeCollect' --组装包装采集事务
	set @LotId=''
	set @LotStatus=''
	set @LotQty=0
	set @LotProductId=''
	set @LotWorkflowId=''
	set @LotWorkflowStepId=''
	set @LotSpecificationId=''
	set @LotSpecificationName=''
	set @ScanTempCount=0
	set @CollectCount=0
	set @CollectSN=''
	set @DataChainAssemblyId=''
	set @CollectSettingId=''
	set @WorkcenterId=''
	set @WorkcenterName=''
	set @ItemName=''
	set @NextItemName=''
	set @ScanQty=0
	set @IsAssemblyStep=0
	set @CollectItemId=''
	set @OrderFieldSettingId=''
	set @sql=''
	set @SNItem=''
	set @SNValue=''
	set @OrderSetItemId=''
	set @FinishQty=0
	set @i=0
	set @TempStr=''
	set @index=0
	set @TempItemName=''
	set @TempItemValue=''

	--转换
	set @LotSN=UPPER(LTRIM(RTRIM(@LotSN)))
	set @ItemValue=UPPER(LTRIM(RTRIM(@ItemValue)))
	set @Operator=UPPER(RTRIM(LTRIM(@Operator)))

	

	CREATE TABLE #CollectTemp(
		ID int,
		CollectName nvarchar(50) NULL,
		CollectSN nvarchar(50) NULL
	)

	--如果参数不为空，则写入表变量
	if ISNULL(@CollectStr,'')<>''
	begin
		set @i=0
		declare cursor1 cursor for 
		select parameter_Value from dbo.ConvertParameterToTable(@CollectStr,';')
		open cursor1
		fetch next from cursor1 
		into @TempStr
		while @@fetch_status=0     
		begin	
			set @i=@i+1
			set @index=0

			set @TempItemName=''
			set @TempItemValue=''

			set @index=CHARINDEX(',',@TempStr)
			set @TempItemName=SUBSTRING(@TempStr,0,@index)
			set @TempItemValue=SUBSTRING(@TempStr,@index+1,LEN(@TempStr))
			
			--写入表变量数据
			insert into #CollectTemp(
					ID,
					CollectName,
					CollectSN)
				values(
					@i,
					@TempItemName,
					@TempItemValue
					)
				
			fetch next from cursor1 
			into @TempStr
		end 
		close cursor1
		deallocate cursor1 
	end

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

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:请输入订单号!'
		set @I_ExceptionFieldName='OrderName'
		return -1
	end
	
	--检查是否为空
	if ISNULL(@MOId,'')=''
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:请输入工单号!'
		set @I_ExceptionFieldName='MOName'
		return -1
	end

	--采集项值为空
	if ISNULL(@ItemValue,'')=''
	begin
		select 
			Product_CollectSetting.Sequence,
			CollectItem.CollectItemName,
			#CollectTemp.CollectSN 
		from Product_CollectSetting
		inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
		left join #CollectTemp on #CollectTemp.CollectName=CollectItem.CollectItemName
		where Product_CollectSetting.ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 
		order by Product_CollectSetting.Sequence

		select '' as LotSN,'' as ItemValue,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:请扫描采集项!'	
		return -1
	end

	-- Add by Wang AL 2020.08.31
    IF CHARINDEX('、', @ItemValue) > 0 -- OR CHARINDEX('，', @ItemValue) > 0
    BEGIN 
        SELECT  '' AS LotSN, '' AS ItemValue, 'error.png' AS WarnImage;
        SET @I_ReturnMessage = 'ServerMessage:采集项中包含中文字符，请切换输入法再扫描!';	
        RETURN -1;
    END; 
	--检查工号是否存在
	if not exists(select 1 from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:作业员 ['+@Operator+'] 无效，请检查!'
		set @I_ExceptionFieldName='Operator'
		return -1
	end
	
	if not exists(select 1 from Lot where LotSN=@LotSN)
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品批号 ['+@LotSN+'] 不存在（未启动），请检查!'
		set @I_ExceptionFieldName='LotSN'
		return -1
	end

	--获取 Lot 信息
	select 
		@LotId=LotId,
		@LotQty=Qty,
		@LotStatus=LotStatus,
		@LotProductId=ProductId,
		@LotWorkflowId=WorkflowId,
		@LotSpecificationId=SpecificationId,
		@LotWorkflowStepId=WorkflowStepId
	from  Lot 
	where LotSN=@LotSN

	--检查LotSN是否被锁定 1代表可用，0代表锁定
	if ISNULL(@LotStatus,1)<>'1'
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品批号 [ '+@LotSN+' ] 状态不可用，无法对其操作!'	
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

	if ISNULL(@WorkcenterId,'')=''
	begin
		select '' as ID,'' as CollectName,'' as CollectSN

		select '' as LotSN,'' as ItemValue,'' as CollectStr,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:用户 ['+@I_OrBitUserName+'] 或者资源 ['+@I_ResourceName+'] 未绑定线体，不允许操作!'
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

	--获取订单信息
	select 
		@OrderFieldSettingId=OrderFieldSettingId
	from OrderFieldSetting 
	where OrderName=@OrderName

	--获取 Lot 规程名称
	select 
		@LotSpecificationName=SpecificationRoot.SpecificationName
	from   SpecificationRoot 
	inner join Specification on SpecificationRoot.DefaultSpecificationId=Specification.SpecificationId
	where Specification.SpecificationId=@LotSpecificationId

	--获取未完成采集的采集项
	select top 1 
		@CollectSettingId=Product_CollectSettingId,
		@Sequence=Sequence,
		@ItemName=CollectItem.CollectItemName
	from Product_CollectSetting 
	inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
	where ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 
		and CollectItem.CollectItemName not in (select distinct CollectName as CollectItemName from #CollectTemp)
	order by Product_CollectSetting.Sequence

	--检查是否已扫描完
	if ISNULL(@CollectSettingId,'')=''
	begin
		--返回网格数据
		select 
			Product_CollectSetting.Sequence,
			CollectItem.CollectItemName,
			#CollectTemp.CollectSN 
		from Product_CollectSetting
		inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
		left join #CollectTemp on #CollectTemp.CollectName=CollectItem.CollectItemName
		where Product_CollectSetting.ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 
		order by Product_CollectSetting.Sequence
			
		select '' as ItemValue,'error.png' as WarnImage	
		set @I_ReturnMessage='ServerMessage:采集项已扫描完成，不允许再次扫描!'
		return -1
	end

	--检查采集项是否符合检查规则
	exec @return_value=dbo.[Txn_CollectSettingSNCheck]
		@I_ReturnMessage=@I_ReturnMessage output,
		@CollectSettingId=@CollectSettingId,
		@OrderName=@OrderName,
		@MOId=@MOId,
		@LotId=@LotId,
		@LotSN=@LotSN,
		@ItemValue=@ItemValue,
		@CollectStr=@CollectStr
		
	if @return_value=-1
	begin
		--返回网格数据
		select 
			Product_CollectSetting.Sequence,
			CollectItem.CollectItemName,
			#CollectTemp.CollectSN 
		from Product_CollectSetting
		inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
		left join #CollectTemp on #CollectTemp.CollectName=CollectItem.CollectItemName
		where Product_CollectSetting.ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 
		order by Product_CollectSetting.Sequence
		
		select '' as ItemValue,'error.png' as WarnImage
		set @I_ReturnMessage=@I_ReturnMessage
		return -1
	end

	if ISNULL(@CollectStr,'')=''
		set @CollectStr=@ItemName+','+@ItemValue
	else
		set @CollectStr=@CollectStr+';'+@ItemName+','+@ItemValue

	--获取主键ID，并插入临时表
	insert into #CollectTemp(
			CollectName,
			CollectSN
			)
		values(
			@ItemName,
			@ItemValue
			)

	--检查是否已经扫描完成
	--查询中间表采集总数
	select @ScanTempCount=ISNULL(COUNT(distinct CollectName),0) from #CollectTemp

	--查询采集设置表维护采集项总数
	select @CollectCount=ISNULL(COUNT(Product_CollectSetting.Product_CollectSettingId),0)
	from Product_CollectSetting 
	where Product_CollectSetting.ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 

	--如果扫描的采集项已等于设置项数
	if @ScanTempCount=@CollectCount
	begin
		--是否装配节点，是，则需要进行扣料倒冲
		if exists(select top 1 SpecificationId from Specification where SpecificationId=@LotSpecificationId and IsAssemblyStep=1)
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
				--如果扣数不成功，则删除最后一个采集项
				delete #CollectTemp
				set @CollectStr=''

				select 
					Product_CollectSetting.Sequence,
					CollectItem.CollectItemName,
					#CollectTemp.CollectSN 
				from Product_CollectSetting
				inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
				left join #CollectTemp on #CollectTemp.CollectName=CollectItem.CollectItemName
				where Product_CollectSetting.ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 
				order by Product_CollectSetting.Sequence

				select '' as ItemValue,'' as CollectStr,'error.png' as WarnImage				
				set @I_ReturnMessage=@I_ReturnMessage	
				set @I_ExceptionFieldName='LotSN'
				return -1
			end	
		end

		--检查 Lot 是否已存在当前规程的采集项数据，如果已存在，则失效历史记录
		if exists(select top 1 DataChainAssemblyId from DataChainAssembly where LotId=@LotId and SpecificationId=@LotSpecificationId and IsCancel=0)
		begin
			declare mycursor2 cursor for 
			select DataChainAssemblyId from DataChainAssembly where LotId=@LotId and SpecificationId=@LotSpecificationId and IsCancel=0
			open mycursor2
			fetch next from mycursor2 
			into @DataChainAssemblyId
			while @@fetch_status=0     
			begin
				update DataChainAssembly set IsCancel=1 where DataChainAssemblyId=@DataChainAssemblyId
				
				fetch next from mycursor2 
				into @DataChainAssemblyId
			end 
			close mycursor2
			deallocate mycursor2 
		end

		--游标循环写入采集项数据
		declare mycursor cursor for 
		select  
			CollectItem.CollectItemId,
			CollectItem.CollectItemName as ItemName,
			#CollectTemp.CollectSN
		from #CollectTemp 
		inner join CollectItem on CollectItem.CollectItemName=#CollectTemp.CollectName 
		open mycursor
		fetch next from mycursor 
		into @CollectItemId,@ItemName,@CollectSN
		while @@fetch_status=0     
		begin
			if ISNULL(@DataChainId,'')=''
			begin
				--产生DataChain返回数据链Id
				EXEC	[dbo].[TxnBase_DataChainMainLine]
					@DataChainId = @DataChainId OUTPUT,
					@TxnCode =@TxnCode,
					@I_PlugInCommand = @I_PlugInCommand,
					@I_OrBitUserId = @I_OrBitUserId,
					@I_ResourceId = @I_ResourceId,
					@LotId = @LotId,
					@MOId= @MOId,
					@ProductId = @LotProductId,
					@WorkcenterId = @WorkcenterId,
					@SpecificationId = @LotSpecificationId,
					@WorkflowStepId = @LotWorkflowStepId
			end

			--获取表主键Id
			exec SysGetObjectPKId '','DataChainAssembly',@DataChainAssemblyId output
	
			--插入DataChainAssembly 表中
			insert into DataChainAssembly(
					DataChainAssemblyId,
					DataChainId,			
					LotId,
					ProductId,
					MOId,				
					ItemName,
					CollectSN,
					Operator,
					WorkflowId,
					SpecificationId,
					WorkflowStepId,
					WorkcenterId,
					ResourceId,
					UserId
					)
				values(
					@DataChainAssemblyId,
					@DataChainId,				
					@LotId,
					@LotProductId,
					@MOId,			
					@ItemName,
					@CollectSN,
					@Operator,
					@LotWorkflowId,
					@LotSpecificationId,
					@LotWorkflowStepId,
					@WorkcenterId,
					@I_ResourceId,
					@I_OrBitUserId
					)

			fetch next from mycursor 
			into @CollectItemId,@ItemName,@CollectSN
		end 
		close mycursor
		deallocate mycursor 

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


		--删除中间表数据
		delete #CollectTemp
		set @CollectStr=''

		--返回网格数据
		select '' as ID,'' as CollectName,'' as CollectSN
		select '' as LotSN,'' as ItemValue,@FinishQty as FinishQty,'' as CollectStr,'ok.png' as WarnImage
		
		set @I_ExceptionFieldName='LotSN'
		set @I_ReturnMessage=@I_ReturnMessage

		return 0
	end

	--获取下一个采集项
	select top 1 @NextItemName=CollectItem.CollectItemName 
	from Product_CollectSetting 
	inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
	where ProductId=@LotProductId and SpecificationId=@LotSpecificationId and Sequence>@Sequence
		order by Product_CollectSetting.Sequence

	--返回网格数据
	select 
		Product_CollectSetting.Sequence,
		CollectItem.CollectItemName,
		#CollectTemp.CollectSN 
	from Product_CollectSetting
	inner join CollectItem on CollectItem.CollectItemId=Product_CollectSetting.CollectItemId
	left join #CollectTemp on #CollectTemp.CollectName=CollectItem.CollectItemName
	where Product_CollectSetting.ProductId=@LotProductId and Product_CollectSetting.SpecificationId=@LotSpecificationId 
	order by Product_CollectSetting.Sequence

	select @NextItemName as NextItemName,'' as ItemValue,@CollectStr as CollectStr,'right.png' as WarnImage

	set @I_ReturnMessage='ServerMessage:采集项 ['+@ItemValue+'] 采集成功，请继续扫描! ['+@NextItemName+']'
	return 0

END




