
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.04.27>
-- Description:	SMT炉后目检不良采集提交
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCStoveStationDefectSubmit]
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
@I_Parameter nvarchar(100)='',		--插件参数	

@MOId char(12)='',
@MOName nvarchar(50)='',
@Operator nvarchar(50)='',
@LotSN nvarchar(50)='',
@HideInfo nvarchar(500)='',
@Side varchar(10)=''

AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int
	declare @TxnCode varchar(10)
	declare @LotId char(12)
	declare @LotStatus char(1)
	declare @LotProductId char(12)
	declare @LotMOId char(12)
	declare @LotWorkcenterId char(12)
	declare @WorkcenterId char(12)
	declare @LotWorkflowId char(12)
	declare @LotSpecificationId char(12)
	declare @LotWorkflowStepId char(12)
	declare @Info nvarchar(100)
	declare @DefectCode nvarchar(50)
	declare @DefectCodeId char(12)
	declare @DefectLocation nvarchar(50)
	declare @DefectDescription nvarchar(200)
	declare @TempLen int
	declare @DataChainId char(12)
	declare @WorkflowDefectId char(12)
	declare @WorkflowDefectItemId char(12)
	declare @WorkcenterName nvarchar(50)
	declare @DefectDataId char(12)
	declare @PSpecificationName nvarchar(50)
	declare @DCStoveStationScanId char(12)
	DECLARE @DCDefectScanId VARCHAR(12)=''

	set @I_ExceptionFieldName='LotSN'
	set @TxnCode='DC'
	set @return_value=-1
	set @LotId=''
	set @LotProductId=''
	set @LotMOId=''
	set @LotStatus=''
	set @Info=''
	set @DefectCode=''
	set @DefectLocation=''
	set @DefectDescription=''
	set @DataChainId=''
	set @TempLen=0
	set @DefectCodeId=''
	set @WorkcenterId=''
	set @WorkflowDefectId=''
	set @LotWorkflowId=''
	set @WorkflowDefectItemId=''
	set @WorkcenterName=''
	set @DefectDataId=''
	set @PSpecificationName=''
	set @DCStoveStationScanId=''
	set @LotWorkcenterId=''

	set @LotSN=upper(rtrim(@LotSN))

	--操作员不能为空
	if ISNULL(@Operator,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入操作员工号!'
		set @I_ExceptionFieldName='Operator'
		return -1
	end

	--LotSN 不能为空
	if ISNULL(@LotSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入产品条码!'
		set @I_ExceptionFieldName='LotSN'
		return -1
	end

	--不良信息不能为空
	if ISNULL(@HideInfo,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入不良信息!'
		set @I_ExceptionFieldName='DefectLocation'
		return -1
	end

	--检查操作员是否存在
	if not exists(select PersonInfoId from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}操作员工号 ['+@Operator+'] 有误!'
		set @I_ExceptionFieldName='Operator'
		return -1
	end

	--检查 LotSN 是否存在
	if not exists(select LotId from Lot where LotSN=@LotSN)
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}产品条码 ['+@LotSN+'] 不存在!'
		set @I_ExceptionFieldName='LotSN'

		select '' as Info
		select '' as LotSN,'' as HideInfo
		return -1
	end

	--获取Lot信息
	select 
		@LotId=LotId,
		@LotMOId=MOId,
		@LotStatus=LotStatus,
		@LotProductId=ProductId,
		@LotWorkcenterId=WorkcenterId,
		@LotWorkflowId=WorkflowId,
		@LotWorkflowStepId=WorkflowStepId,
		@LotSpecificationId=SpecificationId
	from Lot 
	where LotSN=@LotSN

	if ISNULL(@LotStatus,'0')<>'1'
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}产品条码 ['+@LotSN+'] 状态不可用!'
		set @I_ExceptionFieldName='LotSN'
		select '' as Info
		select '' as MOName,'' as ProductName,'' as MOQtyRequired,'' as NowWoorkflowStep,'' as LotSN
		return -1
	end

	--检查是否允许操作此规程
	exec @return_value=dbo.[SysCheckSpecification]
		@I_ReturnMessage=@I_ReturnMessage output,
		@WorkcenterId=@WorkcenterId output,
		@I_OrBitUserId=@I_OrBitUserId,
		@LotId=@LotId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_ResourceId=@I_ResourceId,
		@I_ResourceName=@I_ResourceName,
		@SpecificationId=@LotSpecificationId

	if @return_value=-1
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}'+@I_ReturnMessage
		select '' as DefectCode,'' as LotSN,'error.png' as WarnImage
		return -1
	end

	--线别不能为空
	if ISNULL(@WorkcenterId,'')=''
	begin
		select '' as LotSN,'' as ItemValue,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:用户 ['+@I_OrBitUserName+'] 或者资源 ['+@I_ResourceName+'] 未绑定线别，不允许操作!'
		return -1
	END
    IF ISNULL(@LotWorkcenterId,'') =''
	   SET @LotWorkcenterId = @WorkcenterId
	SET @WorkcenterId = @LotWorkcenterId

	--从工作中心里面控制是否扣料--
	if exists(select 1 from Workcenter where WorkcenterId=@WorkcenterId and IsClosed=0)
	begin
		--检查是否装配节点
		if exists(select 1 from Specification where SpecificationId=@LotSpecificationId and IsAssemblyStep=1)
		begin
			--检查是否满足扣料，满足则扣料
			exec @return_value=[dbo].[SMTBackflushDoMethod]
				@I_ReturnMessage=@I_ReturnMessage output,
				@I_ResourceId=@I_ResourceId,
				@I_ResourceName=@I_ResourceName,
				@I_OrBitUserId=@I_OrBitUserId,
				@I_OrBitUserName=@I_OrBitUserName,
				@LotSN=@LotSN,
				@MOId=@MOId,                 
				@ProductId=@LotProductId,             
				@WorkcenterId=@WorkcenterId, 
				@Side=@Side,				
				@MakeupNumber=1      
		
			if @return_value=-1
			begin
				set @I_ReturnMessage='ServerMessage:say{Erorr.wav}'+@I_ReturnMessage
				select '' as LotSN,'' as ItemValue,'error.png' as WarnImage
				return -1
			end  
		end 
	end

	--数据采集
	declare cursor1 cursor for  
	select parameter_Value as info from ConvertParameterToTable(@HideInfo,';') where parameter_Value<>''
	open cursor1 
	fetch next from cursor1 
	into @Info
	while @@FETCH_STATUS = 0 
	begin 
		set @DefectLocation=UPPER(SUBSTRING(@Info,1, CHARINDEX(',',@Info,1)-1))
		set @DefectCode=UPPER(REPLACE(@Info,@DefectLocation+',',''))

		--获取不良代码ID
		set @DefectCodeId=''
		select 
			@DefectCodeId=DefectCodeId,
			@DefectDescription=DefectCodeDescription
		from DefectCode
		where DefectCodeName=@DefectCode

		--申请采集表主键
		exec SysGetObjectPKId '','DCStoveStationScan',@DCStoveStationScanId output
		set @DefectDataId=@DCStoveStationScanId

		--申请数据链ID
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
				@MOId=@LotMOId,
				@ProductId = @LotProductId,
				@WorkcenterId = @WorkcenterId,
				@SpecificationId = @LotSpecificationId,
				@WorkflowStepId = @LotWorkflowStepId

			--更新不良记录为1
			if exists(select WorkflowDefectid from WorkflowDefect where LotId=@LotId)
			begin
				--begin tran
					update WorkflowDefect set IsExe=1,modifydate=GETDATE(),UserId=@I_OrBitUserId where LotId=@LotId
				--commit tran
			end

			--写入不良记录表
			exec SysGetObjectPKId '','WorkflowDefect',@WorkflowDefectId output
			insert into WorkflowDefect(
					WorkflowDefectId,
					LotId,
					LotSN,
					MOId,
					WorkcenterId,
					DefectWorkflowStepId,
					DefectSpecificationId,
					DefectDataId
					)
				values(
					@WorkflowDefectId,
					@LotId,
					@LotSN,
					@LotMOId,
					@LotWorkcenterId,
					@LotWorkflowStepId,
					@LotSpecificationId,
					@DefectDataId
					)
		end

		exec SysGetObjectPKId '','WorkflowDefectItem',@WorkflowDefectItemId output
		insert into WorkflowDefectItem(
				WorkflowDefectItemId,
				WorkflowDefectId,
				DefectLocation,
				DefectCode
				)
			values(
				@WorkflowDefectItemId,
				@WorkflowDefectId,
				@DefectLocation,
				@DefectCode
				)

		
			  exec SysGetObjectPKId '','DCDefectScan', @DCDefectScanId output 
			  INSERT INTO dbo.DCDefectScan (DCDefectScanId,DataChainId,LotId,LotSN,MOId,
			                                 WorkflowDefectid,ProductId,Operator,Side,
			                                 SpecificationId,DefectLocation,DefectCode,
			                                 DefectDescription,WorkflowId,WorkflowStepId,
			                                 WorkcenterId,ResourceId,UserId,CreateDate)
			  VALUES  (@DCDefectScanId,@DataChainId,@lotid,@lotsn,@Lotmoid,@WorkflowDefectId,@LotProductId,@Operator,'',
			  @LotSpecificationId,@DefectLocation,@DefectCode,@DefectDescription,@LotWorkflowId,@LotWorkflowStepId,@WorkcenterId,@I_ResourceId,@I_OrBitUserId,
			           GETDATE()  -- CreateDate - datetime
			           )

		--写入一行数据
		insert into DCStoveStationScan(
				DCStoveStationScanId,	             
				DataChainId,
				LotId,
				LotSN,
				MOId,	
				ProductId,
				Operator,
				Side,
				DefectLocation,
				DefectCode,
				DefectDescription,
				WorkflowId,
				SpecificationId,
				WorkflowStepId,				
				WorkcenterId,
				ResourceId,
				UserId,
				LockDate,Fixlotsn
				)
			Values(
				@DCStoveStationScanId,	             
				@DataChainId,
				@LotId,
				@LotSN,
				@LotMOId,	
				@LotProductId,
				@Operator,
				@Side,
				@DefectLocation,
				@DefectCode,
				@DefectDescription,
				@LotWorkflowId,
				@LotSpecificationId,
				@LotWorkflowStepId,				
				@WorkcenterId,
				@I_ResourceId,
				@I_OrBitUserId,
				GETDATE(),LEFT(@lotsn,CHARINDEX('-',@lotsn)-1)
				)
		
		fetch next from cursor1 
		into @Info
	end
	close cursor1 
	deallocate cursor1 

	--统计在制品
	EXEC [dbo].[DataChainWIPDoMethod]
		@I_OrBitUserId=@I_OrBitUserId,
		@I_ResourceId=@I_ResourceId,
		@MOId = @LotMOId,
		@LotId = @LotId,
		@WorkcenterId = @WorkcenterId,
		@MoveResult = 'F',
		@Side=@Side

	--传送到下一节点
	EXEC [dbo].[TxnBase_LotMove]
		@I_ReturnMessage=@I_ReturnMessage OUTPUT,
		@I_PlugInCommand=@I_PlugInCommand,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_ResourceId=@I_ResourceId,
		@LotSN=@LotSN 

	set @I_ReturnMessage='ServerMessage:产品条码 ['+@LotSN+'] 不良采集成功!'

	select '' as Info
	select '' as LotSN,'' as DefectLocation,'' as DefectCode,'' as HideInfo

	return 0    
END
