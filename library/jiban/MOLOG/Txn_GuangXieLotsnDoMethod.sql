
-- =============================================
-- Author:		<AMTC MHY >
-- Create date: <2020.7.6>
-- Description:	<启动基板工单Item批号>
-- Rev: 10.00
-- =============================================
CREATE PROCEDURE  [dbo].[Txn_GuangXieLotsnDoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		 --插件命令
@I_OrBitUserId char(12)='',			 --用户ID
@I_OrBitUserName nvarchar(100)='',	 --用户名
@I_ResourceId	char(12)='',		 --资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	 --资源名
@I_PKId char(12) = '',				 --主键
@I_SourcePKId char(12)='',			 --执行拷贝时传入的源主键  
@I_ParentPKId char(12)='',			 --父级主键
@I_Parameter nvarchar(100)='',		 --插件参数	

@NoStartQty VARCHAR(18)='',
@QtyByBox   VARCHAR(18)= '',
@VendorName NVARCHAR(50)='',
@MaterialType NVARCHAR(50)='',
@ReceiveDate NVARCHAR(8)=''

AS
BEGIN
	-- This Stored Procedure is created by OrBit-MetaObject engine
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	declare @StartTime datetime
	declare @EndTime datetime

	declare @return_value int
	declare @LotId char(12)
	declare @LotSN nvarchar(100)             --产生的条码，由N部分组成
	declare @ProductName nvarchar(20)
	declare @MOQtyRequired int
	declare @ApplyQty int                   --已申请数量
	declare @LotSNCount int
	declare @SetDate nvarchar(50)           --日期格式
	declare @Defined nvarchar(50)
	declare @MOItemProductId char(12)
	declare @MOStatus nvarchar(10)
	declare @MOId char(12)
	declare @MOName nvarchar(50)
	declare @MOItemId char(12)
	declare @WorkflowId char(12)
	declare @MOItemLotId char(12)
	declare @SystemMethodLockid char(12)=''	 --方法锁定表ID
	declare @SNCounter INT
    DECLARE @macinfoid VARCHAR(12)=''
	declare @MaxLotSN nvarchar(50)
	declare @TempPN nvarchar(50)
	DECLARE @StartQty DECIMAL(18,4)=0
	declare @SQty INT
	DECLARE @macqty INT = 0
    DECLARE @productid VARCHAR(12)=''
	DECLARE @ShortDes  NVARCHAR(30)=''
	DECLARE @shortmo   varchar(6)=''
	--DECLARE @Materialtype  NVARCHAR(30)=''
	---add by Billy  增加mac 地址  For 2019.08.15
	declare @SOName nvarchar(50)=''  
	declare @MacNo nvarchar(50)=''
	declare @MacType NVARCHAR(10)=''
	DECLARE @prdworkflowid VARCHAR(12)=''
	DECLARE @moproductname VARCHAR(30)=''
	DECLARE @Description NVARCHAR(300)=''
	DECLARE @PrintDate    VARCHAR(10)=''
	DECLARE @VendorCode VARCHAR(5)=''
	DECLARE @Uomid VARCHAR(12)=''
	DECLARE @WorkFlowSteupid VARCHAR(12)
	DECLARE @Specificationid VARCHAR(12)
	DECLARE @I INT =0
	DECLARE @now DATETIME=GETDATE()

	CREATE TABLE #pkitem (id INT ,pkid VARCHAR(12))

	--DECLARE @VendorName NVARCHAR(20)=''
	SET @PrintDate = REPLACE(CONVERT(CHAR,GETDATE(),23),'-','')
	set @SQty=0
	set @StartTime=GETDATE()
	set @EndTime=GETDATE()
	set @return_value=-1
	set @LotId=''
	set @LotSN=''
	set @ProductName=''
	set @MOQtyRequired=0
	set @ApplyQty=0
	set @LotSNCount=0
	set @SetDate=''
	set @Defined=''
	set @MOItemProductId=''
	set @MOStatus=''
	set @MOId=''
	set @MOItemId=''
	set @WorkflowId=''
	set @MOItemLotId=''
	set @SNCounter=0
	set @MaxLotSN=''
	set @MOName=''
	set @TempPN=''

	If ISNULL(@I_PKId,'')='' 
	begin
	   set @I_ReturnMessage='ServerMessage:请选择有效项11!'
	   return -1
	END
    SET @StartQty = CONVERT(DECIMAL,ISNULL(@NoStartQty,'0'))

	if ISNULL(@StartQty,0)=0
	begin
		set @I_ReturnMessage='ServerMessage:请输入启动批号数量!'
	    return -1
	END
    IF ISNULL(@VendorName,'') =''
	BEGIN
      set @I_ReturnMessage='ServerMessage:请输入供应商名!'
	  return -1
	END
	set @VendorCode = dbo.ConvertStrToClumn(@VendorName,'/',2)
	SET @VendorName = dbo.ConvertStrToClumn(@VendorName,'/',1)
	SET @VendorCode=LTRIM(RTRIM(@VendorCode))
	SET @VendorName=LTRIM(RTRIM(@VendorName))
	 IF ISNULL(@MaterialType,'') =''
	BEGIN
      set @I_ReturnMessage='ServerMessage:请输入材质'
	  return -1
	END
    if convert(DECIMAL,ISNULL(@QtyByBox,'0'))=0
	begin
		set @I_ReturnMessage='ServerMessage:请输入启动批号数量!'
	    return -1
	END
	IF ISNULL(@ReceiveDate,'') =''
	BEGIN
      	set @I_ReturnMessage='ServerMessage:请输入入库日期!'
	    return -1
	end
    

	if isnull(@StartQty,0)<=0
	begin
		set @I_ReturnMessage='ServerMessage:启动批号数量必须大于零! '+CAST(@StartQty as varchar)
	    return -1
	end
	IF @VendorCode NOT IN('DXC','KXS','HW','JH','JZ','CY','LPC','JD')
	BEGIN
      set @I_ReturnMessage='ServerMessage:请输入有效的供应商代码'
	    return -1
	END
	--SET @VendorName=''
	--SET @VendorName = CASE @VendorCode WHEN 'DXC' THEN '东旭成'
	--                                   WHEN 'KXS' THEN '凯鑫森'
	--								   WHEN 'HW'  THEN '华威'
	--								   WHEN 'JH' THEN '锦辉'
	--								   WHEN 'JZ' THEN '激智'
	--								   WHEN 'CY' THEN '长阳'
	--								   WHEN 'LPC' THEN '兰埔成'
	--								   END

    IF LEN(@VendorCode) =2
	   SET @VendorCode = '0'+@VendorCode


	

	--if ISNULL(@StartQty,0)>5000
	--begin
	--	set @I_ReturnMessage='ServerMessage:一次启动批号不允许大于 5000，当前 '+CAST(@StartQty as varchar)
	--    return -1
	--end

	--判断是否有运行该程序,有则提示退出--
	delete SystemMethodLock where MethodName=@I_Sender AND CreateDate <= DATEADD(MINUTE,-10,GETDATE())

	if exists(select 1 from SystemMethodLock where MethodName=@I_Sender)
	begin
		set @I_ReturnMessage='ServerMessage:基板计划号启动批号已经在运行,不能重复执行!'
	    return -1
	END
    


	--检查工单明细产品编码是否为空
	select 
		@MOId=MO.MOId,
		@MOName=RTRIM(MO.MOName),
		@MOStatus=MO.MOStatus,              --工单状态
		@MOQtyRequired=MO.MOQtyRequired,      --工单计划数量
		@WorkflowId=MO.WorkflowId,
		@productid =mo.ProductId,
		@SOName=MO.SOName
	from MO WITH(NOLOCK)
	where MOId=@I_PKId

	SELECT @moproductname = productname FROM dbo.ProductRoot nolock WHERE nolock.DefaultProductId = @productid
	SELECT @MOItemId = MOItemId FROM moitem  WHERE moid = @moid AND LineSequence ='0000'


	
   SELECT @sqty =SUM(lotqty) FROM moitemlot WHERE moid = @moid AND DeleteFlag =''
   IF ISNULL(@sqty,0)+ @StartQty > @MOQtyRequired * 1.5
   BEGIN
       set @I_ReturnMessage='ServerMessage:现品号数量已超过工单数量!'
		return -1   
   end 
	
	
  SELECT @WorkFlowSteupid = WorkflowStepId,@Specificationid = SpecificationId 
  FROM dbo.WorkflowStep WITH(NOLOCK) WHERE WorkflowId = @WorkflowId AND IsStartWorkflowStep = 1



	--SELECT TOP 1 @ReceivedDate = REPLACE(CONVERT(CHAR,ModifyDate,23),'-','') FROM dbo.VendorDeliveryItem  WHERE ProductId = @productid ORDER BY VendorDeliveryItemId DESC
 --   IF ISNULL(@ReceivedDate,'') =''
	--  SET @ReceivedDate = REPLACE(CONVERT(CHAR,GETDATE(),23),'-','')
 
	--- 增加千分之五的量
	--TRUNCATE TABLE dbo.RunMonitor
	

	--获取产品名称、产品规则
	select 
		@ProductName=ProductName,@prdworkflowid = WorkflowId,@Description = Product.ProductDescription
	from ProductRoot WITH(NOLOCK)
	inner join Product WITH(NOLOCK) on Product.ProductRootId=ProductRoot.ProductRootId 
	where Product.ProductId=@ProductId
	IF LEFT(@ProductName,3) <>'531'
	BEGIN
        set @I_ReturnMessage='ServerMessage:不是光学组件不能生成批号!'
		return -1
	end

	--获取已申请数量
	select @ApplyQty=sum(ISNULL(LotQty,0)) from MOItemLot where MOId=@MOId and DeleteFlag<>'X'

	
	
	--检查是否已维护工作流
   SET @shortdes =''
   --SET @Materialtype=''
  -- DECLARE @description NVARCHAR(300)=''
  -- SET @Description ='下扩散片/M436A-GX0D-01(材质;COS-D700NF）'
   SELECT @ShortDes =dbo.ConvertStrToClumn(@MaterialType,'/',1)
   SELECT @MaterialType =dbo.ConvertStrToClumn(@MaterialType,'/',2)


 
	SET @shortmo = RIGHT(@MOName,6)
    


	--获取当前工单，最大的流水号，并且转换成 10 进制的整数
	SET @SNCounter ='001'
	if exists(select 1 from MOItemLot where MOId=@MOId  AND ISNULL(DeleteFlag,'') <>'X')
	begin
		DECLARE @TempLotSN TABLE ( LotSN VARCHAR(100) );
        INSERT  INTO @TempLotSN ( LotSN )     SELECT  LotSN       FROM    MOItemLot WITH ( NOLOCK )
        WHERE   MOId = @moid AND DeleteFlag <> 'X';

         SELECT  @MaxLotSN = MAX(LotSN) FROM    @TempLotSN;
		SELECT @SNCounter=[dbo].[ConvertDecimalTo10](10,RIGHT(@MaxLotSN,LEN('000')))
		
	end
	else
		set @SNCounter=0


	DECLARE @PreBarcode VARCHAR(50)=''
	SET @PreBarcode=SUBSTRING(@ProductName,4,4)+right(@ProductName,2)+RTRIM(@VendorCode) +RIGHT(RTRIM(@ReceiveDate),6)+RIGHT(RTRIM(@PrintDate),6)
 --  PRINT @moid + '/'+ @PreBarcode
	--RETURN 0
   
   --IF EXISTS(SELECT TOP 1 1 FROM moitemlot WITH(NOLOCK) WHERE moid = @moid AND DeleteFlag <>'X')
   --BEGIN
   --    SELECT @MaxLotSN = MAX(lotsn) FROM moitemlot WITH(NOLOCK) WHERE moid=@moid AND DeleteFlag <>'X'
	  -- SELECT @SNCounter=[dbo].[ConvertDecimalTo10](10,RIGHT(@MaxLotSN,LEN('000')))
   --END
    
   IF ISNULL(@SNCounter,0) +  CEILING(@StartQty / @QtyByBox) >998
   begin
     delete SystemMethodLock where SystemMethodLockId=@SystemMethodLockid
	 set @I_ReturnMessage='ServerMessage:启动的批次号超过了 999张，请检查!'
	 return -1
   end
   
  DECLARE  @itemlot TABLE (id INT IDENTITY(1,1),
                           lotsn varchar(50),
						   lotqty DECIMAL(18,4),
						   productid VARCHAR(12),
						   Lotid VARCHAR(12))
 DECLARE  @itemlot2 TABLE (lotsn varchar(50),
						   lotqty DECIMAL(18,4),
						   productid VARCHAR(12),
						   Lotid VARCHAR(12))

  DECLARE @Aaddlot TABLE(id INT IDENTITY(1,1),
                           lotsn varchar(50),
						   lotqty DECIMAL(18,4),
						   productid VARCHAR(12),
						   Lotid VARCHAR(12))
 DECLARE @Aadditemlot TABLE(id INT IDENTITY(1,1),
                           lotsn varchar(50),
						   lotqty DECIMAL(18,4),
						   productid VARCHAR(12),
						   Lotid VARCHAR(12))
	


   SET @VendorCode =dbo.RemoveZero(@VendorCode)

		--循环写入
		while @StartQty>0
		begin
			--启动数 1 ，防止死循环			

		
			set @SNCounter=@SNCounter+1
			set @SQty=@SQty+1
			IF @StartQty < @QtyByBox
			  SET @QtyByBox = @StartQty

			---add by billy  For 2019.08.15 检查是否有预置Mac地址
			SET @macno =''
			SET @MacType = ''
			set @macinfoid=''

		
			set @LotSN=''
			set @TempPN=''
			set @TempPN=REPLACE(RIGHT(@ProductName,3),'S','M')


		 set @LotSN=SUBSTRING(@ProductName,4,4)+right(@ProductName,2)+RTRIM(@VendorCode) +RIGHT(RTRIM(@PrintDate),6)+RIGHT(RTRIM(@shortmo),6)+[dbo].[Convert10ToDecimal](@SNCounter,3,10) 
          INSERT INTO @itemlot (lotsn, lotqty, productid)
             VALUES (@LotSN,@QtyByBox,@productid)

			set @StartQty=@StartQty - @QtyByBox
		END
		---增MOITEMLOT
   
				   
   -- add lot表

   IF  EXISTS ( SELECT TOP 1 1
                     FROM moitemlot a WITH (NOLOCK)
                     INNER JOIN @itemlot b ON b.lotsn=a.lotsn )
    BEGIN    
	
	    set @I_ReturnMessage='ServerMessage:启动已启动不能重复启动，请检查!'
	    RETURN -1

	end
    
	 

      INSERT INTO @Aaddlot (lotsn, lotqty, productid)
            SELECT a.lotsn, a.lotqty, a.productid
               FROM @itemlot a
              
      SELECT @i=MAX(id)
         FROM @Aaddlot

      TRUNCATE TABLE #pkitem
      INSERT INTO #pkitem (id, pkid)
            EXEC dbo.SysGetObjectPKIdBatch @ObjectId='', -- char(12)
               @ObjectName=N'lot', -- nvarchar(100)
               @RowCount=@i-- int

      --insert into dbo.Lot (LotId, LotSN, ProductId, LotStatus, OriginalQty,
      --                     Qty, MOId, MOItemId, MOItemTaskId, OrderName,
      --                     PriorityLevel, UOMId, ShiftId, CellId, BoxId, BoxSN,
      --                     IsQCMark, WorkcenterId, ResourceId, VendorId,
      --                     VendorLotSN, CustomerId, CustomerLotSN, WorkflowId,
      --                     WorkflowStepId, SpecificationId, IsMoveIn,
      --                     NextWorkflowStepId, PreviousWorkflowStepId,
      --                     LatestTxnCode, LatestUserId, LatestMoveDate,
      --                     LatestActivityDate, ParentLotId, CreateDate)
      --      SELECT b.pkid,a.lotsn,a.productid,'1',a.lotqty,a.lotqty, @moid, @MOItemId, '', @SOName,'',
			   --    @uomid,'','','','',0,'','','',a.lotsn,'','',@WorkflowId,@WorkFlowSteupid,@Specificationid,1,
				  -- '','','LotStart','',GETDATE(),GETDATE(),'',GETDATE()
                 
               --FROM @Aaddlot a
               --inner JOIN #pkitem b ON b.id=a.id 					


    
	--UPDATE a SET a.lotid = c.pkid  FROM  @itemlot a
	--     INNER JOIN @Aaddlot b ON b.lotsn = a.lotsn 
	--	 INNER  JOIN #pkitem c ON c.id = b.id

	--UPDATE a SET a.lotid = b.lotid FROM @itemlot a
	--     INNER JOIN lot b WITH(NOLOCK) ON b.lotsn = a.lotsn 
	--	 WHERE ISNULL(a.lotid,'') = '' 


 
            INSERT INTO @Aadditemlot (lotsn, lotqty, productid,lotid)
                  SELECT a.lotsn, a.lotqty, a.productid,a.lotid
                     FROM @itemlot a
                     LEFT JOIN moitemlot b ON b.lotsn=a.lotsn
                     WHERE b.lotsn IS null
            SELECT @i=MAX(id)
               FROM @Aadditemlot

            TRUNCATE TABLE #pkitem
            INSERT INTO #pkitem (id, pkid)
                  EXEC dbo.SysGetObjectPKIdBatch @ObjectId='', -- char(12)
                     @ObjectName=N'moitemlot', -- nvarchar(100)
                     @RowCount=@i-- int

            insert into MOItemLot (MOItemLotId, MOId, MOItemId, ProductId,
                                   LotId, LotSN, LotQty, MacNo, Mactype)
                  SELECT b.pkid, @moid, @MOItemId, a.productid, @lotid,
                        a.lotsn, a.lotqty,
                        RTRIM(@VendorName)+RTRIM(@ShortDes)+'/'+RTRIM(@Materialtype),
                        @VendorCode
                     FROM @Aadditemlot a
                     inner JOIN #pkitem b ON b.id=a.id 




	DECLARE @StartLotSN NVARCHAR(50)=''
	DECLARE @EndLotSN NVARCHAR(50)=''
	--获取产品SN申请总数
	select @LotSNCount=COUNT(LotSN),@StartLotSN=MIN(lotsn),@EndLotSN=MAX(lotsn) from moitemlot WITH(NOLOCK) where MOId=@I_PKId AND DeleteFlag =''
	UPDATE mo SET MODescription = RTRIM(@StartLotSN) + ';' + RTRIM(@EndLotSN) WHERE moid = @I_PKId

	set @EndTime=GETDATE()

	set @I_ReturnMessage='ServerMessage:产品批号启动成功，数量: ['+CAST(@SQty as nvarchar)+'] PCS 请查看产品批号选项卡! 耗时 '+CAST(DATEDIFF(SECOND,@StartTime,@EndTime) as varchar)+' 秒.'
	
	insert into QueryLog(MethodName,ResourceId,UserId,StartDate,EndDate)values('Txn_LotStartInBaseplateDoMethod',@I_ResourceId,@I_OrBitUserId,@StartTime,@EndTime)

	return 0

END
--delete SystemMethodLock where SystemMethodLockId='SML100007WVV'

--SELECT DISTINCT DeleteFlag  FROM moitemlot 



--SELECT mact  FROM macinfo
----SELECT * FROM moitemlot



--SELECT * FROM mo a
--  INNER JOIN dbo.Product b ON b.ProductId = a.ProductId AND b.prdname LIKE '515%' 
--  WHERE a.CreateDate >= '2019-08-01'
--  SELECT * FROM lot WHERE moid = 'MOD100005R6Q'




--DELETE FROM  dbo.SystemMethodLock WHERE CreateDate >= '2019-08-15'

--SELECT * FROM  mo WHERE moname = '001010321265'
--DELETE  FROM lot WHERE moid = 'MOD100005R6Q'









