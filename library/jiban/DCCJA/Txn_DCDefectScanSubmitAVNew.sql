
-- =============================================
-- Author:		<MTC She Zhenzhen>
-- Create date: <2017.04.18>
-- Description:不良品采集提交
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_DCDefectScanSubmitAVNew]
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
@DefectWorkflowStepId char(12)='',
@HideInfo nvarchar(500)='',
@HideLotSn VARCHAR(50)='',
@pcblotsn varchar(50)='',
@DefectSourceArea nvarchar(50) = ''
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
	declare @LotWorkcenterId char(12)
	declare @LotWorkflowId char(12)
	declare @LotSpecificationId char(12)
	declare @LotWorkflowStepId char(12)
	declare @nextworkflowstepid char(12)
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
	declare @DCDefectScanId char(12)
	declare @Side varchar(10)
	declare @MESTxnObjectName nvarchar(50)='DCDefectScanAV'
	declare @QTY nvarchar(10)=''	
	--DECLARE @pcblotsn VARCHAR(40)=''
	DECLARE @templotsn VARCHAR(40)=''
	DECLARE @templotid VARCHAR(12)=''
	declare @InDate datetime =null
	DECLARE @DefectAssemblelyScanid VARCHAR(12)=''
	set @InDate = getdate()
	set @I_ExceptionFieldName='LotSN'
	set @TxnCode='DC'
	set @return_value=-1
	set @LotId=''
	set @LotProductId=''
	set @LotMOId=''
	set @LotStatus=''
	set @LotWorkcenterId=''
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
	set @DCDefectScanId=''

	set @DefectLocation=UPPER(@DefectLocation)
	set @DefectCode=UPPER(@DefectCode)
	set @LotSN=UPPER(@HideLotSn)
	set @Operator=UPPER(@Operator)

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
		set @I_ReturnMessage='ServerMessage:请输入产品条码!'
		set @I_ExceptionFieldName='LotSN'
		return -1
	end

	--不良信息不能为空
	if ISNULL(@HideInfo,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请输入不良信息!'
		set @I_ExceptionFieldName='DefectCode'
		return -1
	end

	--检查操作员是否存在
	if not exists(select PersonInfoId from PersonInfo where PersonNumber=@Operator and IsActivity=1)
	begin
		set @I_ReturnMessage='ServerMessage:操作员工号 ['+@Operator+'] 有误!'
		set @I_ExceptionFieldName='Operator'
		return -1
	end

	--不良节点不能为空
	if ISNULL(@DefectWorkflowStepId,'')=''
	begin
		set @I_ReturnMessage='ServerMessage:请选择不良节点!'
		set @I_ExceptionFieldName='DefectWorkflowStepName'
		select 'error.png' as WarnImage
		return -1
	end

	--检查 LotSN 是否存在
	if not exists(select LotId from Lot where LotSN=@LotSN)
	begin
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@LotSN+'] 不存在!'
		set @I_ExceptionFieldName='LotSN'

		select '' as Info
		select '' as HideInfo,'error.png' as WarnImage
		return -1
	end

	--IF EXISTS(SELECT CollectSN FROM DCDefectScan a LEFT JOIN DataChainAssembly b ON b.LotId=a.LotId WHERE CollectSN=(SELECT CollectSN FROM DataChainAssembly WHERE  LotId=@LotId))
	--BEGIN
	--	SET @I_ReturnMessage='ServerMessage:PCBA条码已经维修过!'
	--END

	--获取Lot信息
	SET @templotsn = @lotsn
	SELECT 
		@LotId=LotId,
		@LotMOId=MOId,
		@LotStatus=LotStatus,
		@LotProductId=ProductId,
		@LotWorkcenterId=WorkcenterId,
		@LotWorkflowId=WorkflowId,
		@LotWorkflowStepId=WorkflowStepId,
		@nextworkflowstepid = Nextworkflowstepid,
		@LotSpecificationId=SpecificationId
	from Lot WITH(NOLOCK)
	where LotSN=@LotSN


    IF ISNULL(@LotId, '') = ''
        BEGIN
		   if right(rtrim(@lotsn),4) <> 'AVSN'
            SET @templotsn = RTRIM(@LotSN) + 'AVSN'
			--SET @pcblotsn = @lotsn
            SELECT  @LotId = LotId ,
                    @LotMOId = MOId ,
                    @LotStatus = LotStatus ,
                    @LotProductId = ProductId ,
                    @LotWorkcenterId = WorkcenterId ,
                    @LotWorkflowId = WorkflowId ,
                    @LotWorkflowStepId = WorkflowStepId ,
					@nextworkflowstepid = Nextworkflowstepid,
                    @LotSpecificationId = SpecificationId
            FROM    Lot WITH(NOLOCK)
            WHERE   LotSN = @lotsn
	
        END
  --   ELSE
  --   BEGIN
  --       SELECT TOP 1 @templotid = lotid,@pcblotsn = CollectSN FROM dbo.DataChainAssembly WITH(NOLOCK)
		--     WHERE lotid = @lotid  AND itemname = '基板SN' ORDER BY DataChainAssemblyId desc
		 
	 --END
     


	if ISNULL(@LotStatus,'0')<>'1'
	begin
		set @I_ReturnMessage='ServerMessage:产品条码 ['+@LotSN+'] 状态不可用!'
		set @I_ExceptionFieldName='LotSN'
		select '' as LotInfo
		select '' as LotSN,'' as DefectLocation,'' as DefectCode,'' as HideInfo,'' as MOName,'' as ProductName,
			'' as DefectWorkflowStepName,'' as WorkcenterName,'error.png' as WarnImage
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
		set @I_ReturnMessage=@I_ReturnMessage + @LOTSN
		Select '' as Info
		select '' as LotSN,'' as DefectLocation,'' as DefectCode,'' as HideInfo,'' as MOName,'' as ProductName,
			'' as DefectWorkflowStepName,'' as WorkcenterName,'error.png' as WarnImage
		return -1
	end

	if ISNULL(@LotWorkflowStepId,'')<>ISNULL(@DefectWorkflowStepId,'')
	begin
	       select @PSpecificationName=SpecificationRoot.SpecificationName from Specification 
				inner join SpecificationRoot on Specification.SpecificationRootId=SpecificationRoot.SpecificationRootId 
						where Specification.SpecificationId=@LotSpecificationId
			select '' as LotInfo
			select '' as DefectLocation,'' as DefectCode,'' as HideInfo,'error.png' as WarnImage
			
			set @I_ReturnMessage='ServerMessage:系统检测到批号当前节点为['+@PSpecificationName+'],与选择不良节点不一致，请检查！'
			return -1		
	end
	--else
	--begin
	--	--检查下一节点是否维修节点
	--	if not exists(select 1 from WorkflowPath where WorkflowId=@LotWorkflowId and WorkflowStepId=@LotWorkflowStepId 
	--		and SelectCondition ='CheckIsDefect_PathCondition')
	--	begin	
		
	--		select '' as LotInfo
	--		select '' as DefectLocation,'' as DefectCode,'' as HideInfo,'error.png' as WarnImage
			
	--		set @I_ReturnMessage='ServerMessage:系统检测到不良节点未维护维修节点的 [路径选择存储过程]'
	--		return -1
	--	end
	--end
	--数据采集
	--SELECT @pcblotsn = lotsn FROM lot WHERE lotid = @lotid
	declare cursor1 cursor for  
	select parameter_Value as info from ConvertParameterToTable(@HideInfo,';') where parameter_Value<>''
	open cursor1 
	fetch next from cursor1 
	into @Info
	while @@FETCH_STATUS = 0 
	begin 
		set @DefectLocation=UPPER(SUBSTRING(@Info,1, CHARINDEX(',',@Info,1)-1))
		set @DefectCode=UPPER(REPLACE(@Info,@DefectLocation+',',''))

		IF ISNULL(@LotWorkflowId,'') =''
		BEGIN
		   SELECT @LotWorkflowId = workflowid FROM lot WHERE lotsn = @LotSN	
		end 

		--获取不良代码ID
		set @DefectCodeId=''
		select 
			@DefectCodeId=DefectCodeId,
			@DefectDescription=DefectCodeDescription
		from DefectCode
		where DefectCodeName=@DefectCode

		--申请采集表主键
		exec SysGetObjectPKId '','DCDefectScan',@DCDefectScanId output
		set @DefectDataId=@DCDefectScanId

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
				@SpecificationId = @LotWorkflowStepId,
				@WorkflowStepId =@LotWorkflowStepId

			--更新不良记录为1
			if exists(select WorkflowDefectid from WorkflowDefect where LotId=@LotId)
			begin
				
					update WorkflowDefect set IsExe=1,modifydate=GETDATE(),UserId=@I_OrBitUserId WHERE LotId=@LotId AND ISNULL(isexe,'') = 0

			END
           		
			--写入不良记录表
			exec SysGetObjectPKId '','WorkflowDefect',@WorkflowDefectId output
			insert into WorkflowDefect(
					WorkflowDefectId,
					LotId,
					LotSN,
					pcblotsn,
					MOId,
					WorkcenterId,
					DefectWorkflowId,
					DefectWorkflowStepId,
					DefectSpecificationId,
					DefectDataId
					)
				values(
					@WorkflowDefectId,
					@LotId,
					@lotsn,
					@pcblotsn,
					@LotMOId,
					@LotWorkcenterId,
					@LotWorkflowId,
					@LotWorkflowStepId,
					@LotSpecificationId,
					@DefectDataId
					)
		end
		 IF NOT EXISTS(SELECT DefectAssemblelyScanid FROM DefectAssemblelyScan WHERE PcbLotSn = @lotsn 
			           AND BindserialNO = @templotsn)
			BEGIN
              exec SysGetObjectPKId '','DefectAssemblelyScan',@DefectAssemblelyScanid OUTPUT
              INSERT INTO DefectAssemblelyScan(DefectAssemblelyScanid,
			                              workflowdefectid,
			                              pcblotsn,
										  lotid,
										  moid,
										  bindSerialNo,
										  Createuserid)
						VALUES(@DefectAssemblelyScanid,
						       @WorkflowDefectId,
						       @pcblotsn,
							   @lotid,
							   @lotmoid,
							   @lotsn,
							   @I_OrBitUserId)

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

		--写入一行数据
		insert into DCDefectScan(
				DCDefectScanId,	 
				Workflowdefectid,            
				DataChainId,
				LotId,
				LotSN,
				MOId,	
				ProductId,
				Operator,
				DefectLocation,
				DefectCode,
				DefectDescription,
				WorkflowId,
				SpecificationId,
				WorkflowStepId,				
				WorkcenterId,
				ResourceId,
				UserId,
				DefectSourceArea
				)
			Values(
				@DCDefectScanId,
				@Workflowdefectid,	             
				@DataChainId,
				@LotId,
				@lotsn,
				@LotMOId,	
				@LotProductId,
				@Operator,
				@DefectLocation,
				@DefectCode,
				@DefectDescription,
				@LotWorkflowId,
				@LotSpecificationId,
				@LotWorkflowStepId,				
				@WorkcenterId,
				@I_ResourceId,
				@I_OrBitUserId,
				@DefectSourceArea
				)
				
		fetch next from cursor1 
		into @Info
	end
	close cursor1 
	deallocate cursor1 

	--统计不良数量--
	select @QTY=convert(nvarchar(10),count(lotid)) from (select LotId from DCDefectScan where moid=@LotMOId  group by Lotid) a

	--统计在制品
	EXEC [dbo].[DataChainWIPDoMethod]
		@I_OrBitUserId=@I_OrBitUserId,
		@I_ResourceId=@I_ResourceId,
		@MOId = @LotMOId,
		@LotId = @LotId,
		@WorkcenterId = @WorkcenterId,
		@MoveResult = 'F'

	--传送到下一节点
	IF ISNULL(@nextworkflowstepid,'') =''
	BEGIN
        SELECT TOP 1  @nextworkflowstepid = a.ToWorkflowStepId
                 FROM   WorkflowPath a
                        INNER JOIN dbo.WorkflowStep b ON ( a.WorkflowId = b.WorkflowId
                                                           AND a.ToWorkflowStepId = b.WorkflowStepId
                                                         )
                 WHERE  a.WorkflowId = @LotWorkflowId
                        AND a.WorkflowStepId = @LotWorkflowStepId
                        AND b.SpecificationId = 'SPE100000191'


	end



     declare @workflowstepname nvarchar(50)=''
       EXEC @return_value=[dbo].[TxnBase_LotNonStdMove]
			@I_ReturnMessage = @I_ReturnMessage OUTPUT,
			@I_PlugInCommand = @I_PlugInCommand,
			@I_OrBitUserId = @I_OrBitUserId,
			@I_ResourceId =  @I_ResourceId,
			@LotSN =@LotSN,
			@LotInDate = @InDate,
			@TxnCode='Repaire',
			@TargetWorkflowId = @LotWorkflowId ,
			@TargetWorkflowStepId = @nextworkflowstepid,
			@UserComment= '产线维修'

		   if @return_value=-1
		   begin
			  select @workflowstepname=WorkflowStepName from WorkflowStep 
			  where WorkflowId=@LotWorkflowId and WorkflowStepId=@lotWorkflowStepId
			  select '' as LotSN
			  set @I_ReturnMessage=@I_ReturnMessage	 +  '/' + isnull(@workflowstepname,'')  + '/' + @lotsn
			  return -1
		   end




	--EXEC [dbo].[TxnBase_LotMove]
	--	@I_ReturnMessage=@I_ReturnMessage OUTPUT,
	--	@I_PlugInCommand=@I_PlugInCommand,
	--	@I_OrBitUserId=@I_OrBitUserId,
	--	@I_ResourceId=@I_ResourceId,
	--	@LotSN=@LotSN 

	select '' as LotInfo
	select '' as DefectLocation,'' as DefectCode,'' as HideInfo,'' as LotSN,@QTY as QTY,'' as DefectWorkflowStepName,'OK.png' as WarnImage
	
	set @I_ReturnMessage='ServerMessage:产品条码 ['+@LotSN+'] 不良采集成功!'
	set @I_ExceptionFieldName='LotSN'
	return 0    
END