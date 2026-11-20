
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.04.27>
-- Description:	SMT炉后目检不良采集显示
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCStoveStationDefectShow]
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
@MOName nvarchar(50)='',            --工单号   
@MOQtyRequired float=0, 
@ProductName nvarchar(50)='',
@WorkcenterName nvarchar(50)='',
@ProductDescription nvarchar(500)='',
@Operator nvarchar(50)='',          --操作员
@LotSN nvarchar(50)='',             --产品条码
@Side varchar(10)=''                --面别   

AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int
	declare @LotId char(12)
	declare @LotStatus char(1)
	declare @ProductId char(12)
	declare @LotSpecificationId char(12)
	declare @MESTxnObjectName nvarchar(50)       --事务对象名称
	declare @SpecificationId char(12)
	declare @SpecificationName nvarchar(50)
	declare @WorkcenterId char(12)
	declare @NowWorkflowStep nvarchar(50)  --当前节点
	declare @LotWorkflowStepId char(12)
	declare @LotProductId char(12)
	declare @LotMOId char(12)
	declare @WorkflowId char(12)
	declare @WorkflowStepId char(12)
	declare @MOProductId char(12)
	declare @likestr                 nvarchar(30)='' 
	declare @toworkflowstepid        nvarchar(12)=''
	declare @botcount    int = 0
	declare @MOItemId   nvarchar(12)=''

	set @I_ExceptionFieldName='LotSN'
	set @MESTxnObjectName='DC StoveStation DefectScan'
	set @return_value=-1
	set @LotId=''
	set @ProductId=''
	set @LotStatus=''
	set @LotSpecificationId=''
	set @SpecificationId=''
	set @WorkcenterId=''
	set @SpecificationName=''
	set @NowWorkflowStep=''
	set @LotWorkflowStepId=''
	set @LotProductId=''
	set @LotMOId=''
	set @WorkflowId=''
	set @WorkflowStepId=''
	set @MOProductId=''

	--转换为大写
	set @LotSN=UPPER(RTRIM(LTRIM(@LotSN)))

	if ISNULL(@I_Sender,'')='DefaultScanShow'
	begin
		select @MOId as MOId, @MOName as MOName,@ProductName as ProductName,@WorkcenterName as WorkcenterName,@MOQtyRequired as MOQtyRequired
		,@ProductDescription as ProductDescription,@Operator as Operator,@Side as Side
		if isnull(@Operator,'')=''
		begin
			set @I_ReturnMessage='ServerMessage:请扫描操作员工号!'
			set @I_ExceptionFieldName='Operator'
		end
		else
		begin
			set @I_ReturnMessage='ServerMessage:请扫描条码!'
			set @I_ExceptionFieldName='LotSN'
		end
		return 0
	end


	--检查是否为空
	if ISNULL(@MOId,'')=''
	begin		
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入工单号!'
		set @I_ExceptionFieldName='MOName'

		select '' as Info
		select '' AS Operator,'' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end

	--操作员是否为空
	if ISNULL(@Operator,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入操作员工号!'
		set @I_ExceptionFieldName='Operator'

		select '' as Info
		select '' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end

	--检查人员工号是否存在
	if not exists(select PersonInfoId from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}操作员工号 ['+@Operator+'] 不存在或已离职!'
		set @I_ExceptionFieldName='Operator'

		select '' as Info
		select '' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end

	--LotSN 不能为空
	if ISNULL(@LotSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入产品条码!'

		select '' as Info
		select '' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end

	--获取MO信息
	select 
		@MOId=MOId,
		@MOProductId=ProductId,
		@WorkflowId=WorkflowId,
		@MOQtyRequired=MOQtyRequired
	from MO 
	where MOName=@MOName

	--检查工单是否存在
	if ISNULL(@MOId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}工单号 ['+@MOName+'] 输入有误!'
		set @I_ExceptionFieldName='MOName'

		select '' as LotInfo
		select '' AS Operator,'' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end


	--获取Lot信息
	select 
		@LotId=LotId,
		@LotStatus=LotStatus,
		@SpecificationId=SpecificationId
	from Lot 
	where LotSN=@LotSN

  --检查 LotSN 是否存在
	if ISNULL(@LotId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}产品条码 ['+@LotSN+'] 不存在!'
		set @I_ExceptionFieldName='LotSN'
		select '' as Info
		select '' as LotSN,'' as HideInfo
		return -1
	end

	if ISNULL(@LotStatus,'0')<>'1'
	begin		
		select '' as Info
		select '' as LotSN,'' as HideInfo,'error.png' as WarnImage

		set @I_ExceptionFieldName='LotSN'
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}产品条码 ['+@LotSN+'] 状态不可用!'

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
		@SpecificationId=@SpecificationId,
		@MESTxnObjectName=@MESTxnObjectName

	if @return_value=-1
	begin	
		set @I_ReturnMessage=@I_ReturnMessage

		select '' as LotInfo
		select '' as LotSN,'error.png' as WarnImage
		return -1
	end
		
	--检查线别说是否为空
	if ISNULL(@WorkcenterId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:用户 ['+@I_OrBitUserName+'] 或者资源 ['+@I_ResourceName+'] 未维护线别!'
		set @I_ExceptionFieldName='MOName'

		select '' as Info
		select '' as Operator,'' as LotSN,'' as HideInfo,'error.png' as WarnImage

        return -1
	end
	--	--检查当前线体是否存在此面别的在制信息
	--if not exists(select top 1 WorkcenterWIPId from WorkcenterWIP where MOId=@MOId and WorkcenterId=@WorkcenterId and Side=@Side)
	--begin
	--	set @I_ReturnMessage='ServerMessage:当前线体不存在此面别 ['+@Side+'] 的工单在制信息，请检查!'
	--	select '' as LotSN,'error.png' as WarnImage
	--	return -1
	--end

	--返回界面数据
	select '' as LotInfo
	select '' as DefectLocation,'' as DefectCode,'' as HideInfo,'ok.png' as WarnImage

	set @I_ExceptionFieldName='DefectLocation'
	set @I_ReturnMessage='ServerMessage:请输入不良信息!'

	return 0   
END