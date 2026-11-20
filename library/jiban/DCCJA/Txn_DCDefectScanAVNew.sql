
-- =============================================
-- Author:		<OBit Team Phoenix>
-- Create date: <2016.04.28>
-- Description:	DIP不良采集
-- =============================================
Create PROCEDURE  [dbo].[Txn_DCDefectScanAVNew]
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

@SOName nvarchar(50)='',
@Operator nvarchar(50)='',
@LotSN nvarchar(50)='',
@DefectLocation nvarchar(100)='',
@DefectCode nvarchar(50)='',
@HideInfo nvarchar(500)='',
@HideLotSN VARCHAR(50)=''

AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @return_value int
	declare @LotId char(12)
	declare @LotStatus char(1)
	declare @ProductId char(12)
	declare @MOId char(12)
	declare @LotSpecificationId char(12)
	declare @LotSpecificationName nvarchar(50)
	declare @WorkcenterId char(12)
	declare @MESTxnObjectName nvarchar(50)
	declare @i int
	declare @TempLocation nvarchar(50)
	declare @TempCode nvarchar(50)
	declare @index int
	declare @TempStr nvarchar(100)

	set @I_ExceptionFieldName='DefectCode'
	set @MESTxnObjectName='DCDefectScanAV'
	set @return_value=-1
	set @LotId=''
	set @ProductId=''
	set @MOId=''
	set @LotStatus=''
	set @LotSpecificationId=''
	set @LotSpecificationName=''
	set @WorkcenterId=''
	set @i=0
	set @TempLocation=''
	set @TempCode=''
	set @index=0
	set @TempStr=''

	--转换大写
	set @DefectLocation=UPPER(@DefectLocation)
	set @DefectCode=UPPER(@DefectCode)
	set @LotSN=UPPER(@HideLotSN)
	set @Operator=UPPER(@Operator)

	CREATE TABLE #CollectTemp(
		ID int,
		DefectLocation nvarchar(50) NULL,
		DefectCode nvarchar(50) NULL
	)

	--重置扫描
	if @I_Sender='DefectClear'
	begin
		select '' as LotInfo
		select '' as DefectLocation,'' as DefectCode,'' as HideInfo,'' AS HideLotSN

		set @I_ExceptionFieldName='LotSN'
		set @I_ReturnMessage='ServerMessage:数据清除成功，请重新输入不良位置!'
		return 0
	end

	--操作员是否为空
	if ISNULL(@Operator,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入操作员工号!'
		set @I_ExceptionFieldName='Operator'
		select 'error.png' as WarnImage
        return -1
	end

	--检查人员工号是否存在
	if not exists(select PersonInfoId from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		set @I_ReturnMessage='ServerMessage:操作员工号 ['+@Operator+'] 不存在或已离职!'
		set @I_ExceptionFieldName='Operator'
		select ''as LotInfo
		select 'error.png' as WarnImage
        return -1
	end

	--LotSN 不能为空
	if ISNULL(@LotSN,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入产品条码!'

		select ''as LotInfo
		select '' as LotSN,'' AS HideLotSN , 'error.png' as WarnImage
        return -1
	end

	--检查 LotSN 是否存在
	if not exists(select LotId from Lot where LotSN=@LotSN)
	begin	
		select '' as LotInfo
		select '' as LotSN,'' as HideInfo,'' as MOName,'' as ProductName,'' AS HideLotSN,
	'' as WorkcenterName, 0 AS Qty,'' as ProductDescription	

		set @I_ExceptionFieldName='LotSN'
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@LotSN+'] 不存在!'

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
		select '' as LotSN,'' as HideInfo,'error.png' as WarnImage,'' AS HideLotSN

		set @I_ExceptionFieldName='LotSN'
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@LotSN+'] 状态不可用!'

		return -1
	end

	--不良代码不能为空
	if ISNULL(@DefectCode,'')=''
	begin		
		set @I_ExceptionFieldName='DefectCode'
		set @I_ReturnMessage='ServerMessage:请输入不良代码,在不良位置按Enter添加不良信息!'
		return -1
	end
	
	--检查是否允许操作此规程
	exec @return_value=dbo.[SysCheckSpecification]
		@I_ReturnMessage=@I_ReturnMessage output,
		@WorkcenterId=@WorkcenterId output,
		@LotId=@LotId,
		@I_OrBitUserId='',
		@I_OrBitUserName='',
		@I_ResourceId='',
		@I_ResourceName='',
		@SpecificationId=@LotSpecificationId,
		@MESTxnObjectName=@MESTxnObjectName

	if @return_value=-1
	begin	
		set @I_ReturnMessage='ServerMessage:'+@I_ReturnMessage
		select 'error.png' as WarnImage
		return -1
	end	

	--检查不良代码是否存在
	if not exists(select 1 from DefectCode where DefectCodeName=@DefectCode)
	begin		
		set @I_ExceptionFieldName='DefectCode'
		set @I_ReturnMessage='ServerMessage:不良代码 ['+@DefectCode+'] 无效!'
		return -1
	end

	--拼接字符串
	if @HideInfo=''
		set @HideInfo=@DefectLocation+','+@DefectCode
	else
		set @HideInfo=@HideInfo+';'+@DefectLocation+','+@DefectCode

	--如果参数不为空，则写入表变量
	if ISNULL(@HideInfo,'')<>''
	begin
		set @i=0
		declare cursor1 cursor for 
		select parameter_Value from dbo.ConvertParameterToTable(@HideInfo,';')
		open cursor1
		fetch next from cursor1 
		into @TempStr
		while @@fetch_status=0     
		begin	
			set @i=@i+1
			set @index=0

			set @TempLocation=''
			set @TempCode=''

			set @index=CHARINDEX(',',@TempStr)
			set @TempLocation=SUBSTRING(@TempStr,0,@index)
			set @TempCode=SUBSTRING(@TempStr,@index+1,LEN(@TempStr))
			
			--写入表变量数据
			insert into #CollectTemp(
					ID,
					DefectLocation,
					DefectCode)
				values(
					@i,
					@TempLocation,
					@TempCode
					)
				
			fetch next from cursor1 
			into @TempStr
		end 
		close cursor1
		deallocate cursor1 
	end

	--返回界面数据
	select DefectLocation as _DefectLocation,DefectCode as _DefectCode from #CollectTemp order by ID
	select '' as DefectLocation,'' as DefectCode,@HideInfo as HideInfo

	set @I_ReturnMessage='ServerMessage:请继续输入不良信息!'

	return 0    
END