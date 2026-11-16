

-- =============================================
-- Author:		<smf>
-- Create date: <2017.02.09 >
-- Description:	<维修产品失效组装绑定记录>
-- =============================================
CREATE PROCEDURE [dbo].[Txn_RepairUnbindDoMethod] 
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

@MOName nvarchar(50)='',            --工单号
@ProductName NVARCHAR(50)='',
@LotSN NVARCHAR(50)=''

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
	declare @MESTxnObjectId char(12)  --事务对象名称ID
	declare @MESTxnObjectDesc nvarchar(200) --事务描述
	DECLARE @SpecificationId CHAR(12)
	DECLARE @MOId CHAR(12)
	DECLARE @ProductId CHAR(12)
	DECLARE @DeleteFlag CHAR(1)
	DECLARE @RepairUnbindId CHAR(12)
	DECLARE @LotId CHAR(12)
	DECLARE @LotSpecificationid CHAR(12)
	DECLARE @LotSpecificationName NVARCHAR(50)
	DECLARE @pcbasn  VARCHAR(50)
	DECLARE @ToWorkflowStepId VARCHAR(12)=''
	DECLARE @WorkflowId varchar(12)=''
	DECLARE @InDate DATETIME
	DECLARE @workflowstepid VARCHAR(12)=''
	DECLARE @lotworkflowstepid VARCHAR(12)=''
	DECLARE @defaultspecificationid VARCHAR(12)=''
	SET @defaultspecificationid = 'SPE100000191'
	
	set @return_value=-1
	set @I_ExceptionFieldName='LotSN'	
	set @TxnCode='DC'
	set @MESTxnObjectName='Repair Unbinding'
	set @Date=GETDATE()
	set @MESTxnObjectId=''
	set @MESTxnObjectDesc=''
	SET @SpecificationId=''
	SET @MOId=''
	SET @ProductId=''
	SET @DeleteFlag=''
	SET @RepairUnbindId=''
	SET @LotId=''
	SET @LotSpecificationid=''
	SET @LotSpecificationName=''
	SET @InDate = GETDATE()
	--转换大写
	set @LotSN=UPPER(RTRIM(LTRIM(@LotSN)))


	IF ISNULL(@lotsn,'') =''
	BEGIN
        select '' as LotSN,'error.png' as WarnImage

		set @I_ReturnMessage='ServerMessage:批号不能为空!'
		SET @I_ExceptionFieldName = 'lotsn'
		return -1
	end
	
	
	--获取事务对象ID
	select 
		@MESTxnObjectId=MESTxnObjectId,
		@MESTxnObjectDesc=MESTxnObjectDesc 
	from MESTxnObject 
	where MESTxnObjectName=@MESTxnObjectName

	--检查是否已维护事务规程
	if not exists(select top 1 MESTxnObjectSpecificationId from MESTxnObjectSpecification where MESTxnObjectId=@MESTxnObjectId)
		or (select COUNT(MESTxnObjectSpecificationId) from MESTxnObjectSpecification where MESTxnObjectId=@MESTxnObjectId)>1
	begin
		select '' as LotSN,'error.png' as WarnImage

		set @I_ReturnMessage='ServerMessage:事务 ['+@MESTxnObjectDesc+'] 规程维护有误，请检查!'
		return -1
	end

	--获取事务对象规程ID
	select top 1 @SpecificationId=SpecificationId from MESTxnObjectSpecification where MESTxnObjectId=@MESTxnObjectId

	--检查事务对象规程是否为空
	if ISNULL(@SpecificationId,'')=''
	begin		
		select '' as LotSN,'error.png' as WarnImage

		set @I_ReturnMessage='ServerMessage:MES事务对象 ['+@MESTxnObjectName+'] 规程为空,请维护!'
		set @I_ExceptionFieldName='MOName'	
		return -1
	END
	SET @lotid=''
	SET @WorkflowId =''
	 SELECT @lotid = lotid FROM dbo.DataChainAssembly WITH(NOLOCK) WHERE CollectSN = @lotsn AND IsCancel = 0

	 

    IF ISNULL(@LotId, '') = ''
        BEGIN      
            SELECT  @MOId = MOId ,
                    @ProductId = ProductId ,
                    @LotId = LotId ,
					@lotworkflowstepid = WorkflowStepId,
                    @LotSpecificationid = Lot.SpecificationId ,
                    @WorkflowId = WorkflowId
            FROM    Lot WITH ( NOLOCK )
            WHERE   LotSN = @LotSN
                    AND LotStatus = 1; 


        END;
    IF ISNULL(@WorkflowId,'') = ''
	BEGIN
       SELECT  @MOId = MOId ,
                    @ProductId = ProductId ,
                    @LotId = LotId ,
					@lotworkflowstepid = WorkflowStepId,
                    @LotSpecificationid = Lot.SpecificationId ,
                    @WorkflowId = WorkflowId
            FROM    Lot WITH ( NOLOCK )
            WHERE   Lotid = @lotid
                    AND LotStatus = 1; 
	END
    
	IF ISNULL(@WorkflowId,'')=''
	BEGIN
        SELECT '' as LotSN,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:找不到对应的工作流!' 
		set @I_ExceptionFieldName='MOName'	
		return -1

	end

	IF EXISTS( SELECT TOP 1 WW_FGInventoryId FROM dbo.WW_FGInventory WHERE lotid = @lotid AND IsCancel = 0)
	BEGIN
      	select '' as LotSN,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品已入库不能进行解绑!'
		set @I_ExceptionFieldName='MOName'	
		return -1
	END
    
	IF EXISTS( SELECT TOP 1 ShipBoxId FROM dbo.ShipBox WHERE lotid = @lotid AND IsCancel = 0)
	BEGIN
      	select '' as LotSN,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品已包装不能进行解绑!' + @lotid
		set @I_ExceptionFieldName='MOName'	
		return -1
   end
   IF ISNULL(@LotSpecificationId, '') IN ( 'SPE100000192', 'SPE100000193', 'SPE100000195', 'SPE100000197',
                                                    'SPE100000198', 'SPE10000019X', 'SPE1000001BP' )
	 BEGIN
	    Select '' as LotSN,'error.png' as WarnImage
		set @I_ReturnMessage='ServerMessage:产品已入后段包装不能进行解绑!' + @lotid
		set @I_ExceptionFieldName='MOName'	
		return -1

	 END




	
	--检查资源或者用户是否允许操作此规程
	exec @return_value=dbo.[SysCheckSpecification]
		@I_ReturnMessage=@I_ReturnMessage output,
		@lotid=@lotid,
		@I_OrBitUserId=@I_OrBitUserId,
		@I_OrBitUserName=@I_OrBitUserName,
		--@I_ResourceId=@I_ResourceId,
		--@I_ResourceName=@I_ResourceName,
		@SpecificationId=@SpecificationId

	if @return_value=-1
	begin
		select '' as LotSN,'error.png' as WarnImage
		set @I_ReturnMessage=@I_ReturnMessage +'0' + @lotid
		return -1
	end

		

	SELECT @LotSpecificationName=dbo.SpecificationRoot.SpecificationName FROM dbo.SpecificationRoot WHERE DefaultSpecificationId=@LotSpecificationid

	SET @pcbasn =''
	SELECT @pcbasn = CollectSN FROM dbo.DataChainAssembly  WHERE lotid=@lotid AND SpecificationId='SPE10000018S' AND IsCancel=0 
	    AND LEFT(CollectSN,3) IN('515','514','513','512')
	IF ISNULL(@pcbasn,'') =''
	BEGIN
	  SET @I_ReturnMessage='ServerMessage:组装上线时没有绑定PCB 板的SN！'+ @LOTID
		RETURN -1	
	END 
	--失效组装上线记录
	--IF PATINDEX('%维修%',@LotSpecificationName)>0
	--BEGIN
		--BEGIN TRAN
			UPDATE dbo.DataChainAssembly SET IsCancel=1 WHERE lotid=@lotid AND SpecificationId='SPE10000018S' AND IsCancel=0
		--COMMIT TRAN
	--END
 --   ELSE
 --   BEGIN
	--	SET @I_ReturnMessage='不属于维修产品，不允许失效组装绑定记录！'
	--	RETURN -1
	--END

	--SELECT * FROM dbo.SpecificationRoot WHERE SpecificationName = '整机维修'
    
	

	SET @ToWorkflowStepId =''
	
	SELECT TOP 1 @workflowstepid = a.workflowstepid,@ToWorkflowStepId=a.ToWorkflowStepId 
	FROM 	WorkflowPath a
	  INNER JOIN dbo.WorkflowStep b ON b.WorkflowId = a.WorkflowId AND a.ToWorkflowStepId = b.WorkflowStepId 
	  WHERE a.WorkflowId=@WorkflowId AND  a.WorkflowStepId = @lotworkflowstepid AND b.SpecificationId = @defaultspecificationid
   
   IF ISNULL(@ToWorkflowStepId,'') =''
   BEGIN
      SELECT TOP 1 @workflowstepid =a.workflowstepid,@ToWorkflowStepId=a.ToWorkflowStepId FROM 
	WorkflowPath A
	inner JOIN workflowstep b ON(b.WorkflowStepId = a.toWorkflowStepId AND b.WorkflowId = A.WorkflowId  )
	 WHERE a.WorkflowId=@WorkflowId AND  b.SpecificationId = @defaultspecificationid ORDER BY a.WorkflowStepId desc
   end

    IF ISNULL(@ToWorkflowStepId,'') =''
   BEGIN
       SET @I_ReturnMessage='ServerMessage:工作流中没有定义好返工流程！'+ @LOTID
		RETURN -1
   end


	--非标传送到返工节点
	EXEC @return_value=[dbo].[TxnBase_LotNonStdMove]
		@I_ReturnMessage = @I_ReturnMessage OUTPUT,
		@I_PlugInCommand = @I_PlugInCommand,
		@I_OrBitUserId = @I_OrBitUserId,
		@I_ResourceId =  @I_ResourceId,
		@LotSN =@LotSN,
		@LotInDate = @InDate,
		@TxnCode='Rebinding',
		@TargetWorkflowId = @WorkflowId ,
		@TargetWorkflowStepId = @ToWorkflowStepId,
		@UserComment = '手动扫入维修'

	if @return_value=-1
	begin
		select '' as LotSN
		set @I_ReturnMessage=@I_ReturnMessage	+ @lotid	
		return -1
	end

	--申请主键
	EXEC dbo.SysGetObjectPKId @ObjectId = '', -- char(12)
	    @ObjectName = N'RepairUnbind', -- nvarchar(100)
	    @PKID = @RepairUnbindId OUTPUT -- char(12)
	
	INSERT INTO RepairUnbind(
		RepairUnbindId,
		pcba_sn,
		workflowid,
		workflowStepid,
		LotId,
		MOId,
		LotSN,
		SpecificationId,
		UserId
	)VALUES(
		@RepairUnbindId,
		@pcbasn,
		@WorkflowId,
		@ToWorkflowStepId,
		@LotId,
		@MOId,
		@LotSN,
		@LotSpecificationid,
		@I_OrBitUserId
	)

	EXEC [dbo].[TxnBase_LotMove] 
			@I_ReturnMessage=@I_ReturnMessage OUTPUT,
			@I_OrBitUserId =@I_OrBitUserId,
			@I_ResourceId =@I_ResourceId ,
			@LotSN =@LotSN ,
			@lotInDate = @InDate


	
	SELECT '' AS lotsn,'' AS moname,'' AS productname,''AS ProductDescription,'OK.png' as WarnImage
	SET @I_ReturnMessage='ServerMessage:维修LotSN['+@LotSN+']绑定组装记录失效成功！'
	SET @I_ExceptionFieldName = 'lotsn'
	RETURN 0    

END

