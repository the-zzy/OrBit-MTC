
-- =============================================
-- Author:		<OrBit Phoenix>
-- Create date: <2016.11.28>
--Create date: <2018.03.14>
-- Description:	成品重量采集
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCFGWeightCollectTest]
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
@I_Parameter nvarchar(100)='',      --插件参数

--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
@Operator nvarchar(50)='',
@FGQTY decimal(18,2)=0 output,			--已扫描数量
@ScanLotSn nvarchar(50)='',
@Productid char(12)='',
@OrderName nvarchar(50)='',
@gWeight nvarchar(50)=''

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
	declare @WorkcenterId char(12)
	declare @LotWorkflowId char(12)
	declare @LotSpecificationId char(12)
	declare @LotWorkflowStepId char(12)
	declare @IsFGWeight varchar(1)
	declare @FGWeightMax decimal(18,2)
	declare @FGWeightMin decimal(18,2)
	declare @DataChainId char(12)
	declare @WorkflowDefectId char(12)
	declare @WorkflowDefectItemId char(12)
	declare @WorkcenterName nvarchar(50)
	declare @PSpecificationName nvarchar(50)
	declare @DCWeightCollectId char(12)
	declare @Enter nvarchar(50)=''
	declare @MESTxnObjectName nvarchar(50)='DC FGWeight Collect Test'			

	set @I_ExceptionFieldName='ScanLotSN'
	set @TxnCode='DC'
	set @return_value=-1
	set @LotId=''
	set @LotProductId=''
	set @LotMOId=''
	set @LotStatus=''
	set @IsFGWeight='N'
	set @FGWeightMax =0
	set @FGWeightMin=0
	set @DataChainId=''
	set @WorkcenterId=''
	set @WorkflowDefectId=''
	set @LotWorkflowId=''
	set @WorkflowDefectItemId=''
	set @WorkcenterName=''
	set @PSpecificationName=''
	set @DCWeightCollectId=''


	--OrderName 不能为空
	if ISNULL(@OrderName,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入订单号!'+@Enter
		set @I_ExceptionFieldName='OrderName'
		return -1
	end

	--操作员不能为空
	if ISNULL(@Operator,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入操作员工号!'+@Enter
		set @I_ExceptionFieldName='Operator'
		return -1
	end	


	--检查操作员是否存在
	if not exists(select PersonInfoId from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		set @I_ReturnMessage='ServerMessage:操作员工号 ['+@Operator+'] 有误!'+@Enter
		set @I_ExceptionFieldName='Operator'
		return -1
	end
	
	--LotSN 不能为空
	if ISNULL(@ScanLotSn,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入产品条码!'+@Enter
		set @I_ExceptionFieldName='ScanLotSN'
		return -1
	end

	--获取订单信息
	if not exists(select 1 from OrderFieldSetting where OrderName=@OrderName)
	begin
		set @I_ReturnMessage='ServerMessage:没有订单号 ['+@OrderName+']!'+@Enter
		set @I_ExceptionFieldName='OrderName'
		return -1
	end

	--检查 LotSN 是否存在
	if not exists(select LotId from Lot where LotSN=@ScanLotSN)
	begin
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@ScanLotSN+'] 不存在!'+@Enter
		set @I_ExceptionFieldName='ScanLotSN'
		return -1
	end

	--获取Lot信息
	select 
		@LotId=LotId,
		@LotMOId=MOId,
		@OrderName=ordername,
		@LotStatus=LotStatus,
		@LotProductId=ProductId,
		@LotWorkflowId=WorkflowId,
		@LotWorkflowStepId=WorkflowStepId,
		@LotSpecificationId=SpecificationId
	from Lot 
	where LotSN=@ScanLotSn

	if ISNULL(@LotStatus,'0')<>'1'
	begin
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@ScanLotSN+'] 状态不可用!'+@Enter
		set @I_ExceptionFieldName='ScanLotSN'
		return -1
	end

	----检查是否允许操作此规程
	exec @return_value=dbo.[SysCheckSpecification]
		@I_ReturnMessage=@I_ReturnMessage output,
		@WorkcenterId=@WorkcenterId output,
		@I_OrBitUserId=@I_OrBitUserId,
		@LotId=@LotId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_ResourceId=@I_ResourceId,
		@I_ResourceName=@I_ResourceName,
		@SpecificationId=@LotSpecificationId,
		@MESTxnObjectName=@MESTxnObjectName

	if @return_value=-1
	begin
		set @I_ReturnMessage='ServerMessage:'+@I_ReturnMessage+@Enter
		return -1
	end

	--线别不能为空
	if ISNULL(@WorkcenterId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:用户 ['+@I_OrBitUserName+'] 或者资源 ['+@I_ResourceName+'] 未绑定线别，不允许操作!'+@Enter
		return -1
	end

	if @I_Sender='btnScanLotSn'
	begin
		set @I_ReturnMessage='ServerMessage:请将成品放入电子称上采集重量!'+@Enter
		set @I_ExceptionFieldName='ScanLotSN'
		return 0
	end
	--获取订单设置里面的成品重量
	select 
	@FGWeightMax=ISNULL(FGWeightMax,0),
	@FGWeightMin=ISNULL(FgWeightMin,0),
	@IsFGWeight=ISNULL(IsFgWeight,'N') 
	from OrderFieldSetting 
	where OrderName=@OrderName
	
	--要求成品称重
	if ISNULL(@IsFGWeight,'')='Y'
	begin
		--采集重量格式出错
		if ISNumeric(@gWeight)=0
		begin
			set @I_ReturnMessage='ServerMessage:采集重量格式['+@gWeight+']错误!'+@Enter
			set @I_ExceptionFieldName='ScanLotSN'
			return -1
		end
		--采集重量不能为0
		if convert(decimal(18,2),@gWeight)<=0
		begin
			set @I_ReturnMessage='ServerMessage:没有采集到重量信息!'+@Enter
			set @I_ExceptionFieldName='ScanLotSN'
			return -1
		end
		--查找本地电脑资源是否有设置外箱重量,如果有则用本地的代替工单里面的重量--
		if exists(select 1 from PortSetting where ResourceId=@I_ResourceId and iscancel=0)
		begin 
			select  		
			@FGWeightMax=FGWeightMax ,
			@FGWeightMin =FGWeightMin 
			from PortSetting where ResourceId=@I_ResourceId and iscancel=0
			if isnull(@FGWeightMax,0)<=0
			begin
					
				set @I_ReturnMessage='ServerMessage:本机['+@I_ResourceName+'] 重量上限必须大于零!'
				set @return_value= -2
			end

			if isnull(@FGWeightMin,0)<=0
			begin				
				set @I_ReturnMessage='ServerMessage:本机['+@I_ResourceName+'] 重量下线必须大于零!'
				set @return_value= -2
			end

			if isnull(@FGWeightMax,0) < isnull(@FGWeightMin,0)
			begin
				set @I_ReturnMessage='ServerMessage:本机['+@I_ResourceName+'] 重量上限必须大于重量下限!'
				set @return_value= -2
			end

			if convert(decimal(18,2),@gWeight)<@FGWeightMin
			begin
					
				set @I_ReturnMessage='ServerMessage:成品重量 '+convert(nvarchar(20),@gWeight)+' 不能小于重量下限 '+convert(nvarchar(20),@FGWeightMin)+'!'
				set @return_value= -2
			end

			if convert(decimal(18,2),@gWeight)>@FGWeightMax
			begin
				set @I_ReturnMessage='ServerMessage:成品重量 '+convert(nvarchar(20),@gWeight)+' 不能大于重量上限 '+convert(nvarchar(20),@FGWeightMax)+'!'
				set @return_value= -2
			end	
		 end
		else
		begin

			--订单里面的重量比较--

			if isnull(@FGWeightMax,0)<=0
			begin
					
				set @I_ReturnMessage='ServerMessage:订单 ['+@OrderName+'] 重量上限必须大于零!'
				set @return_value= -2
			end

			if isnull(@FGWeightMin,0)<=0
			begin				
				set @I_ReturnMessage='ServerMessage:订单 ['+@OrderName+'] 重量下线必须大于零!'
				set @return_value= -2
			end

			if isnull(@FGWeightMax,0) < isnull(@FGWeightMin,0)
			begin
				set @I_ReturnMessage='ServerMessage:订单 ['+@OrderName+'] 重量上限必须大于重量下限!'
				set @return_value= -2
			end

			if convert(decimal(18,2),@gWeight)<@FGWeightMin
			begin
				set @I_ReturnMessage='ServerMessage:成品重量 '+convert(nvarchar(20),@gWeight)+' 不能小于重量下限 '+convert(nvarchar(20),@FGWeightMin)+'!'
				set @return_value= -2
			end

			if convert(decimal(18,2),@gWeight)>@FGWeightMax
			begin
				set @I_ReturnMessage='ServerMessage:成品重量 '+convert(nvarchar(20),@gWeight)+' 不能大于重量上限 '+convert(nvarchar(20),@FGWeightMax)+'!'
				set @return_value= -2
			end	
		end						
	end
	else
	begin
		set @I_ReturnMessage='ServerMessage:订单 ['+@OrderName+'] 不用成品称重!'
		return -1
	end
	set @I_ReturnMessage='ServerMessage:产品条码 ['+@ScanLotSn+']采集成功!'+@gWeight
--	return 0 
	--申请采集表主键
	exec SysGetObjectPKId '','DCWeightCollect',@DCWeightCollectId output
	set @DCWeightCollectId=@DCWeightCollectId

	--申请数据链ID
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


	--写入一行数据
	insert into DCWeightCollect(
			DCWeightCollectId,	             
			DataChainId,
			LotId,
			LotSN,
			MOId,	
			ProductId,
			Operator,
			WeightSTR,
			WorkflowId,
			SpecificationId,
			WorkflowStepId,				
			WorkcenterId,
			ResourceId,
			IsPass,
			UserId
			)
		Values(
			@DCWeightCollectId,	             
			@DataChainId,
			@LotId,
			@ScanLotSn,
			@LotMOId,	
			@LotProductId,
			@Operator,
			@gWeight,
			@LotWorkflowId,
			@LotSpecificationId,
			@LotWorkflowStepId,				
			@WorkcenterId,
			@I_ResourceId,
			iif(@return_value=-2,0,1),
			@I_OrBitUserId
			)
	--统计已经扫描的数量--
	select @FGQTY=count(lotid) from DCWeightCollect where moid=@LotMOId and productid=@LotProductId	and isPass=1	

-- 返回值--
	if @return_value=-2
		return  @return_value
	else
	if @return_value=-1
	return -1
	else
	begin
		--传送到下一节点
		EXEC [dbo].[TxnBase_LotMove]
		@I_ReturnMessage=@I_ReturnMessage OUTPUT,
		@I_PlugInCommand=@I_PlugInCommand,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_ResourceId=@I_ResourceId,
		@LotSN=@ScanLotSN 
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@ScanLotSn+']采集成功!'+@Enter
		return 0 
	end	   
END
