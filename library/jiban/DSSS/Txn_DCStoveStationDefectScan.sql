
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.04.28>
-- Description:	SMT炉后目检不良采集
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCStoveStationDefectScan]
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
@DefectLocation nvarchar(100)='',
@DefectCode nvarchar(50)='',
@HideInfo nvarchar(500)='',
@Side varchar(10)='',
@LableNo nvarchar(50)=''

AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int
	declare @LotId char(12)
	declare @LotStatus char(1)
	declare @ProductId char(12)
	declare @LotSpecificationId char(12)
	declare @LotSpecificationName nvarchar(50)
	declare @WorkcenterId char(12)

	set @I_ExceptionFieldName='DefectLocation'
	set @return_value=-1
	set @LotId=''
	set @ProductId=''
	set @LotStatus=''
	set @LotSpecificationId=''
	set @LotSpecificationName=''
	set @WorkcenterId=''

	--转换大写
	set @DefectLocation=UPPER(@DefectLocation)
	set @DefectCode=UPPER(@DefectCode)

	--定义表变量
	declare @TempTable table(
		MOItemId char(12),
		ItemLocation nvarchar(2000)
	)

	--重置扫描
	if @I_Sender='OffLineDefectClear'
	begin
		select '' as LotInfo
		select '' as DefectLocation,'' as DefectCode,'' as HideInfo,'' as LableNo 

		set @I_ExceptionFieldName='LotSN'
		set @I_ReturnMessage='ServerMessage:数据清除成功，请重新输入不良位置!'
		return 0
	end



	--检查是否为空
	if ISNULL(@MOId,'')=''
	begin		
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入工单号!'

		select '' as LotInfo
		select '' AS Operator,'' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end

	--操作员是否为空
	if ISNULL(@Operator,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入操作员工号!'

		select ''as LotInfo
		select '' as Operator,'' as LotSN,'error.png' as WarnImage
        return -1
	end

	--检查人员工号是否存在
	if not exists(select PersonInfoId from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}操作员工号 ['+@Operator+'] 不存在或已离职!'
		
		select ''as LotInfo
		select '' as Operator,'' as LotSN,'error.png' as WarnImage
        return -1
	end

	--获取MO信息
	select @MOId=MOId from MO where MOName=@MOName


	--LotSN 不能为空
	if ISNULL(@LotSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入产品条码!'

		select ''as LotInfo
		select '' as LotSN,'error.png' as WarnImage
        return -1
	end

	--不良位置不能为空
	if ISNULL(@DefectLocation,'')=''
	begin		
		set @I_ExceptionFieldName='DefectLocation'
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入不良位置!'

		return -1
	end

	--不良代码不能为空
	if ISNULL(@DefectCode,'')=''
	begin		
		set @I_ExceptionFieldName='DefectCode'
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}请输入不良代码!'

		return -1
	end

	--检查工单是否存在
	if ISNULL(@MOId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}工单号 ['+@MOName+'] 输入有误!'
		set @I_ExceptionFieldName='DefectCode'

		select '' as LotInfo
		select '' as MOName,'' AS ProductName ,'' as MOQtyRequired,'' AS Operator,'' as LotSN,'' as HideInfo,'error.png' as WarnImage
        return -1
	end

	--检查 LotSN 是否存在
	if not exists(select LotId from Lot where LotSN=@LotSN)
	begin	
		select '' as Info
		select '' as LotSN,'' as HideInfo	

		set @I_ExceptionFieldName='DefectCode'
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}产品条码 ['+@LotSN+'] 不存在!'

		return -1
	end
	

	--获取Lot信息
	select 
		@LotId=LotId,
		@LotStatus=LotStatus,
		@LotSpecificationId=SpecificationId
	from Lot 
	where LotSN=@LotSN

	if ISNULL(@LotStatus,'0')<>'1'
	begin		
		select '' as Info
		select '' as LotSN,'' as HideInfo,'error.png' as WarnImage

		set @I_ExceptionFieldName='DefectCode'
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}产品条码 ['+@LotSN+'] 状态不可用!'

		return -1
	end

	--检查是否允许操作此规程
	exec @return_value=dbo.[SysCheckSpecification]
		@I_ReturnMessage=@I_ReturnMessage output,
		@WorkcenterId=@WorkcenterId output,
		@LotId=@LotId,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		@I_ResourceId=@I_ResourceId,
		@I_ResourceName=@I_ResourceName,
		@SpecificationId=@LotSpecificationId

	if @return_value=-1
	begin	
		set @I_ReturnMessage=@I_ReturnMessage

		select '' as LotInfo
		select '' as LotSN,'error.png' as WarnImage
		return -1
	end

		--检查线别是否为空
	if ISNULL(@WorkcenterId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:用户 ['+@I_OrBitUserName+'] 或者资源 ['+@I_ResourceName+'] 未维护线别!'

		select '' as LotInfo
		select '' as Operator,'' as LotSN,'' as HideInfo,'error.png' as WarnImage

        return -1
	end
	----检查当前线体是否存在此面别的在制信息
	--if not exists(select top 1 WorkcenterWIPId from WorkcenterWIP where MOId=@MOId and WorkcenterId=@WorkcenterId and Side=@Side)
	--begin
	--	set @I_ReturnMessage='ServerMessage:当前线体不存在此面别 ['+@Side+'] 的工单在制信息，请检查!'
	--	select '' as LotSN,'error.png' as WarnImage
	--	return -1
	--end


	--检查不良代码是否存在
	if not exists(select 1 from DefectCode where DefectCodeName=@DefectCode)
	begin		
		set @I_ExceptionFieldName='DefectCode'
		set @I_ReturnMessage='ServerMessage:say{Erorr.wav}不良代码 ['+@DefectCode+'] 无效!'
		return -1
	end

	--拼接字符串
	if @HideInfo=''
		set @HideInfo=@DefectLocation+','+@DefectCode
	else
		set @HideInfo=@HideInfo+';'+@DefectLocation+','+@DefectCode

	--返回界面数据
	select parameter_Value as Info from ConvertParameterToTable(@HideInfo,';') where parameter_Value<>''
	select '' as DefectLocation,'' as DefectCode,@HideInfo as HideInfo,@LableNo as LableNo

	set @I_ReturnMessage='ServerMessage:请继续输入不良信息!'

	return 0    
END