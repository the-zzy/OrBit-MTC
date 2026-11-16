

-- =============================================
-- Author:		<Bill>
-- Create date: <2012.3.15>
-- Description:	PDA插件-物料上架
-- 不用校验规程??
--  
-- ============================================
CREATE  PROCEDURE  [dbo].[PDA_SMTProductRemarkSn_DoMethod]
@I_Sender nvarchar(200)='', --客户端执行按钮
@I_ReturnMessage nvarchar(max)='' output,  --返回的信息,支持多语言
@I_ExceptionFieldName nvarchar(100)='' output, --向客户端报告引起冲突的字段
@I_LanguageId char(1)='1',				--客户端传入的语言ID
@I_PlugInCommand varchar(5)='',		--插件命令
@I_OrBitUserId char(12)='',			--用户ID
@I_OrBitUserName nvarchar(100)='',	--用户名
@I_ResourceId char(12)='',			--资源ID(如果资源不在资源清单中，那么它将是空的)
@I_ResourceName nvarchar(100)='',	--资源名
@I_PKid char(12) ='',				--主键
@I_ParentPKId char(12)='',			--父级主键
@I_Parameter nvarchar(max)='',  		--插件参数
--以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.
 
@Moname nvarchar(20)='',
@WorkCenterName NVARCHAR(30)='',
@SoNtype nvarchar(20)='',
@QtyOfBox VARCHAR(20)='',
@Operator VARCHAR(20)='' ,
@lotSN NVARCHAR(50)=''

 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	DECLARE @MOID VARCHAR(12)=''
	DECLARE @Productname VARCHAR(30)=''
	
	DECLARE @SmtProductionMarkid CHAR(12)=''
	 
	DECLARE @Workcenterid VARCHAR(12)=''
	DECLARE @pkitem TABLE(id INT,pkitemid VARCHAR(12))
	DECLARE @return_value INT =0
	DECLARE @MRZFile VARCHAR(30) = N'SMTMarkCard.mrz'
	DECLARE @SQLString NVARCHAR(2000)=''
	DECLARE @Workercentername VARCHAR(30)=''
	DECLARE @Productid VARCHAR(12)=''
	DECLARE @soname VARCHAR(20)=''
	DECLARE @moqty  DECIMAL(18,4)=0
	DECLARE @i INT =0
	DECLARE @Maxseq INT =1
	DECLARE @lotqty DECIMAL(18,4)=0
	DECLARE @Scanqty DECIMAL(18,4)=0
    DECLARE @RequestQty DECIMAL(18,4)=0
	DECLARE @TotalQty DECIMAL(18,4)=0
	DECLARE @QRSN NVARCHAR(200)=''
	DECLARE @NewSN VARCHAR(50)= 'Init';  --不能修改这个默认值为空，原表中有空值
	DECLARE @list TABLE(id INT IDENTITY(1,1),lotsn VARCHAR(50),wwid VARCHAR(12),
	    Productid VARCHAR(12),lotqty DECIMAL(18,4))
    DECLARE @StockorderItem TABLE(StockIssuedOrderItemId VARCHAR(12),
	      orgqty DECIMAL(18,4),Fixqty DECIMAL(18,4),Workcenterid VARCHAR(12))

	IF @I_Sender ='RevokeBtn'
	BEGIN
		IF ISNULL(@Operator,'') = ''
		BEGIN
			SELECT '' AS Operator,'error.png' AS WarnImg;
            SET @I_ReturnMessage ='ServerMessage:请输入员工工号'	   
			SET @I_ExceptionFieldName ='Operator'        
			RETURN -1
		END 
		ELSE IF NOT EXISTS (SELECT 1 FROM dbo.PersonInfo WHERE PersonNumber=@Operator AND IsActivity=1)
		BEGIN 
			SELECT '' AS Operator,'error.png' AS WarnImg;
			SET @I_ReturnMessage ='ServerMessage:员工工号【'+@Operator+'】不存在或者失效'	  
			SET @I_ExceptionFieldName ='Operator'        
			RETURN -1
		END 


		IF ISNULL(@Moname,'')='' AND ISNULL(@lotSN,'')=''
		BEGIN 
			SELECT '' AS lotSN,'error.png' AS WarnImg;
			SET @I_ReturnMessage ='ServerMessage:工单和批号均为空，输入按照工单撤销还是单箱撤销，请确认！'	  
			SET @I_ExceptionFieldName ='lotSN'        
			RETURN -1
		END 
		 
		SELECT  SmtProductionMarkid ,QtyOfBox
		INTO #RevokeData
		FROM dbo.SmtProductionMark WHERE ( LotSN = @lotSN  OR Moname=@Moname)--AND QtyOfBox>0

		IF NOT EXISTS(SELECT 1 FROM #RevokeData)
		BEGIN  
			SELECT '' AS LotSN,'error.png' AS WarnImg;
			SET @I_ReturnMessage ='ServerMessage:系统暂无打印标志卡信息，请确认'	  
			SET @I_ExceptionFieldName ='Moname'        
			RETURN -1 
		END 

		IF EXISTS (SELECT 1 FROM #RevokeData WHERE   QtyOfBox>0 )
		BEGIN 

			INSERT INTO SmtProductionMarkRevoke
			(	SmtProductionMarkRevokeId
				,RevokeOperator
				,SmtProductionMarkid
				,WorkCenterName
				,Moname
				,Moid
				,QtyOfBox
				,Operator
				,CreateDate
				,CreateUserid
				,Productid
				,QRSN
				,MoRequestqty
				,Productname
				,ProdStatus
				,Soname
				,LotSN
				)
			SELECT dbo.Fn_GetObjectPKId(12,'SmtProductionMarkRevoke',NEXT VALUE FOR SmtProductionMarkRevoke_PK) AS   SmtProductionMarkRevokeId
				,@Operator
				,a.SmtProductionMarkid
				,WorkCenterName
				,Moname
				,Moid
				,a.QtyOfBox
				,Operator
				,CreateDate
				,CreateUserid
				,Productid
				,QRSN
				,MoRequestqty
				,Productname
				,ProdStatus
				,Soname
				,LotSN  FROM SmtProductionMark a
				INNER JOIN #RevokeData b ON b.SmtProductionMarkid = a.SmtProductionMarkid 

			UPDATE a  SET QtyOfBox=0 FROM SmtProductionMark a
			INNER JOIN #RevokeData b ON b.SmtProductionMarkid = a.SmtProductionMarkid 
		
			SELECT '' AS LotSN,'' AS Moname,'ok.png' AS WarnImg;
			SET @I_ReturnMessage ='ServerMessage:撤销成功！'
			SET @I_ExceptionFieldName ='Moname'        
			RETURN 0
		END 
		ELSE
        BEGIN  
			SELECT '' AS LotSN,'error.png' AS WarnImg;
			SET @I_ReturnMessage ='ServerMessage:已经失效（可能已经撤销），请确认'	  
			SET @I_ExceptionFieldName ='Moname'  
			RETURN -1
		END 
		  
	END 
	-- 取已生旧的要补充打印的条码

   IF @I_Sender ='ExportToExcel'
   BEGIN
      SELECT WorkCenterNamE AS '线体',Soname AS '订单号',Moname AS '工单号', LotSN AS '条码', QtyOfBox AS '装板数量',
      	Operator AS '操作员', CreateDate AS '创建时间', Productname AS '料号', ProdStatus AS '生产状态'
	  FROM dbo.SmtProductionMark ORDER BY CreateDate DESC 
     SET @I_ReturnMessage ='Servermessage:导出成功！'
	 RETURN 0
   end
	

	
		IF ISNULL(@Moname,'') = ''
		BEGIN
            SET @I_ReturnMessage ='ServerMessage:工单不能为空'	   
			SET @I_ExceptionFieldName ='Moname'        
	       RETURN -1
		END     
	   SELECT @moid = moid,@Productid = ProductId,@soname = soname,@moqty = MOQtyRequired  FROM mo WHERE RIGHT(MOName,10) = RIGHT(@Moname,10)
	   IF ISNULL(@MOID,'') =''
	   BEGIN
           SET @I_ReturnMessage ='ServerMessage：找不到工单ID'	     
		   SET @I_ExceptionFieldName ='Moname'   
	       RETURN -1
	   END
 
	   SELECT @Productname = productname FROM productroot WHERE DefaultProductId = @Productid
	   IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.PersonInfo WHERE PersonNumber = @Operator AND IsActivity = 1 )
	   BEGIN
           SET @I_ReturnMessage ='ServerMessage：工号不在系统中，请检查'+ @Operator	  
		   SET @I_ExceptionFieldName ='Operator'      
	       RETURN -1
	   END
	   SET @TotalQty =0
	   SELECT @TotalQty = SUM(QtyOfBox) FROM SmtProductionMark WHERE moid = @mOID AND ProdStatus = @SoNtype
	  -- RETURN 0
 
	   IF ISNULL(@TotalQty,0) + CAST(ISNULL(@QtyOfBox,0) AS FLOAT) > @moqty
	   BEGIN
           SET @I_ReturnMessage ='ServerMessage：工单累计已打标识卡数量【 '+RTRIM(CONVERT(CHAR,CAST(ISNULL(@totalqty,0) AS float)))
		        + '】加上本次数量['+ RTRIM(CONVERT(CHAR,CAST(ISNULL(@QtyOfBox,0) AS float)))+']超过了工单数量，请检查'+ @Operator	  
		   SET @I_ExceptionFieldName ='Operator'      
	       RETURN -1
	   end
 
     
    IF @I_Sender ='SMTPrdScaning'
	BEGIN
        SET @I_ReturnMessage ='ServerMessage:请输入装板数量后，按打印输出标签'	 
		SELECT @Productname AS Productname,CAST(@moqty AS FLOAT) AS MoQty,@soname AS Soname
	    SET @I_ExceptionFieldName ='QtyOfBox'       
	    RETURN 0

	end
	 IF ISNULL(@WorkCenterName,'') = ''
		BEGIN
            SET @I_ReturnMessage ='ServerMessage:线体不能为空'	    
			SET @I_ExceptionFieldName ='Workcentername'       
	       RETURN -1
		END	
		  IF  NOT EXISTS(SELECT TOP 1 1 FROM dbo.Workcenter WHERE WorkcenterName = @WorkCenterName AND LEFT(@WorkCenterName,1)  IN('S','D','A'))
		BEGIN
            SET @I_ReturnMessage ='ServerMessage:线体不是SMT 的线体'	+@WorkCenterName    
			SET @I_ExceptionFieldName ='Workcentername'       
	       RETURN -1
		END


      
     --  SELECT @Productname = productname FROM productroot WHERE DefaultProductId = @Productid 

 
    IF @I_Sender ='SmtMarkLabelPrinter'
	BEGIN	  
	--SELECT CONVERT(CHAR,GETDATE(),120)
	 
	    DECLARE @datetxt VARCHAR(10)
	    SET @datetxt = CONVERT(CHAR,GETDATE(),102)
		DECLARE @checi varchar(10) ='1'		

      IF ISNULL(@QtyOfBox,'0') = '0'
	  BEGIN
        SET @I_ReturnMessage ='ServerMessage：要输入装板数量'	  
		   SET @I_ExceptionFieldName ='QtyOfBox'      
	       RETURN -1
	  END
	  
	  IF CAST(ISNULL(@QtyOfBox,'0') AS DECIMAL(18, 4)) <= 0
	  BEGIN
      		SET @I_ReturnMessage ='ServerMessage：要输入装板数量'	  
		    SET @I_ExceptionFieldName ='QtyOfBox'      
	        RETURN -1
	  end
	  
	  IF ISNULL(@SoNtype,'') =''
	  BEGIN
        SET @I_ReturnMessage ='ServerMessage：产品状态要输入'	  
		   SET @I_ExceptionFieldName ='QtyOfBox'      
	       RETURN -1
	  end
	  DECLARE @product TABLE(productid VARCHAR(12),totalQTY DECIMAL(18,4),remark VARCHAR(MAX))
	  


--ALTER TABLE SmtProductionMark ADD Soname  nvarchar(20)
    
	  SET @QRSN =RTRIM(@Moname) + '/' + RTRIM(@soname)+ '/'+@Productname+'/'+RTRIM(CAST(@QtyOfBox AS FLOAT)) +'/'+ CONVERT(CHAR,GETDATE(),120)

	 -- IF EXISTS(SELECT top 1 1 FROM SmtProductionMark WHERE moid= @moid AND WorkCenterName = @WorkCenterName AND QtyOfBox = @QtyOfBox 
	 -- AND DATEDIFF(HOUR,CreateDate,GETDATE()) <=2)  -- 两个小时内不能重新打印同一个条码
	 -- AND  NOT  EXISTS(
		-- SELECT top 1 1 FROM SmtProductionMark WHERE moid= @moid AND WorkCenterName = @WorkCenterName AND QtyOfBox = 0 
	 -- )
	 -- BEGIN
  --      SELECT top 1 @NewSN = LotSN FROM SmtProductionMark WHERE moid= @moid AND WorkCenterName = @WorkCenterName AND QtyOfBox = @QtyOfBox 
		--AND DATEDIFF(HOUR,CreateDate,GETDATE()) <=2
	 -- end
	  
	  IF NOT EXISTS(SELECT TOP  1 1 FROM dbo.SmtProductionMark WHERE LotSN = @NewSN)
	  BEGIN
		EXEC @return_value = [dbo].[Txn_ApplyDeliveryLotSN]
	        @SNCounterName = N'SMT产品标识卡' ,
	        @CounterType = N'R' ,
	 		@VendorId = 'AMTC0' ,  
	        @NewSN = @NewSN OUTPUT; 
	       
	    IF @return_value = -1
	    BEGIN
	    	SET @I_ReturnMessage = 'ServerMessage:批号生成失败,请重新操作一次！';		
	        SET @I_ExceptionFieldName = 'LotSN';
	        RETURN -1;
	    END    
		  
	    EXEC dbo.SysGetObjectPKId
	      @ObjectId = '', -- char(12)
	      @ObjectName = N'SmtProductionMark', -- nvarchar(100)
	      @PKID = @SmtProductionMarkid OUTPUT -- char(12)
	      
	     INSERT INTO dbo.SmtProductionMark
	          ( SmtProductionMarkid,WorkCenterName, Moname, Moid,Productid,MoRequestqty,Soname,
			   QtyOfBox, Operator, CreateDate, CreateUserid,QRSN,Productname,ProdStatus, LotSN)
	      VALUES  (@SmtProductionMarkid,@WorkCenterName,@Moname,@moid,@Productid,@moqty,@Soname,@QtyOfBox,@Operator,
	               GETDATE(),@I_OrBitUserId,@QRSN, @Productname ,@SoNtype, @NewSN)
	   END
	   ELSE
       BEGIN
         SELECT TOP  1 @SmtProductionMarkid = SmtProductionMarkid FROM dbo.SmtProductionMark WHERE LotSN = @NewSN
	   end

	 IF @I_PlugInCommand ='DSSS'
	  BEGIN
	      SELECT TOP 1 LotSN AS QRSN,a.Productname AS Productname,a.Moname,a.soname AS Soname,CAST(a.MoRequestqty AS FLOAT) AS Lotqty,
	        CAST(a.QtyOfBox AS FLOAT) AS QtyOfBox ,a.Operator AS UserName,a.ProdStatus,CONVERT(VARCHAR(10),a.CreateDate,120) AS Productdate,
			a.WorkCenterName AS WorkCenter	   
	       FROM   SmtProductionMark a    WHERE a.SmtProductionMarkid = @SmtProductionMarkid

		SET @I_ReturnMessage ='Servermessage:标识卡打印完成' +@SmtProductionMarkid    

	  END
	  ELSE
	  BEGIN
		
		SELECT TOP 1    @SQLString = ''''+RTRIM(Moname)+''' as Moname,'''+ '' + RTRIM(@WorkcenterName) +''' as WorkCenter,''' 
		  + RTRIM(CAST((@qtyofbox) AS char)) + ''' as QtyofBox,''' + RTRIM(a.Productname) + ''' as ProductName,'''+a.soname+''' as Soname,'''	
		  + rtrim(CAST(a.MoRequestqty AS char)) + ''' as Lotqty,' 	+ RTRIM(a.ProdStatus) + ''' as ProdStatus,'
		  + rtrim(CAST(a.QtyOfBox AS char)) + ''' as Qtyofbox,''' + RTRIM(a.Operator) +''' as Username,''' 
		  + CONVERT(CHAR,a.CreateDate,120) + ''' as Productdate'
		  FROM dbo.SmtProductionMark a	
		    
		  WHERE a.moid = @moid   
		  
		  
 
		SET @SQLString = 'select ' + @SQLString
		--PRINT @SQLString
		--RETURN 


	   EXEC @return_value =dbo.PDA_PrintForAndord	   
	      @I_ReturnMessage=@I_ReturnMessage OUTPUT, -- nvarchar(max)
	      @I_PlugInCommand=@I_PlugInCommand, -- varchar(5)
	      @I_OrBitUserId=@I_OrBitUserId, -- char(12)
	      @I_OrBitUserName=@I_OrBitUserName, -- nvarchar(100)
	      @I_ResourceId=@I_ResourceId, -- char(12)
	      @I_ResourceName=@I_ResourceName, -- nvarchar(100)
	      @PrintLotStr=@SQLString, -- nvarchar(max)
	      @mrzfile=@MRZFile, -- nvarchar(30)
	      @Printer='JIABO' -- varchar(10)  	    

		--UPDATE dbo.StockIssuedOrderSeq SET IsFinsed = 1 WHERE StockIssuedOrderSeqId = @StockIssuedOrderDetailId

	END

        SET @I_ReturnMessage =@I_ReturnMessage     
		SET @I_ExceptionFieldName ='SplitLotSn'
	    RETURN @return_value
        
	   RETURN 0
	end
	
	  
	return 0	
	
END
 





