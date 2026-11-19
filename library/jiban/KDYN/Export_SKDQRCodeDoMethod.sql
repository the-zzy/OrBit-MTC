--------------------------------------------
--  amtc mhy
--  exec [Export_SKDQRCodeDoMethod] @I_PKID =N'KDOI000003E7',@I_Sender=N'ExportPicklistToexcel'
--
---------------------------------------------
CREATE PROCEDURE  [dbo].[Export_SKDQRCodeDoMethod]
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
@I_Parameter nvarchar(100)=''	--插件参数

 --以上变量为系统服务固定接口参数，必须在每一个DoEvent过程中实现.


AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @ordername NVARCHAR(20)='';

	--写入查看日志
	--insert into QueryLog(MethodName,ResourceId,UserId)values('Query_SKDReportNewDoMethod',@I_ResourceId,@I_OrBitUserId)
	
	if ISNULL(@I_PKid,'') =''
	begin
		set @I_ReturnMessage='ServerMessage:请选择订单号!'
		return -1
	END



	IF  @I_Sender='KDOrderCanel'
	BEGIN
    
		UPDATE dbo.KDOrderInfo SET IsCancel=1 WHERE KDOrderInfoId=@I_PKid

		
		SELECT @ordername= OrderName FROM dbo.KDOrderInfo WHERE KDOrderInfoId=@I_PKid

		
		UPDATE [172.16.8.31].OrBitXIZC.dbo.KDOrderInfo SET IsCancel = 1 WHERE OrderName= @ordername

		set @I_ReturnMessage='ServerMessage:此单已作废!'
		return 0
	END




	
	create TABLE #kdqrexport (
	                          br128_1 VARCHAR(5),
	                          OrderDate VARCHAR(12),
							  br128_2 VARCHAR(5),
							  OrderNum varchar(20),
							  br128_3 VARCHAR(5),
							  ORDERQTY DECIMAL(18,4),
							  br128_4 VARCHAR(5),
							  Model   NVARCHAR(30),
							  Br128_5 VARCHAR(5),
							  PartNo VARCHAR(30),
							  Br128_6 VARCHAR(5),
							  ExtDescriptin NVARCHAR(200),
							  Specification NVARCHAR(200),
							  BomQty       DECIMAL(18,4),
							  Shipqty      DECIMAL(18,4),
							  Br128_7 VARCHAR(5),
							  QtyofCarton  DECIMAL(18,4),
							  BoxAmount INT,
							  Br128_8 VARCHAR(5),
							  BonNo  VARCHAR(10),
							  BoxType VARCHAR(5),
							  Kdboxinfoid VARCHAR(12),
							  Parentbox   VARCHAR(10),
							  Motherbox VARCHAR(10),
							  Parentboxinfoid VARCHAR(12),
							  Qrcode NVARCHAR(MAX)
							      
	)

	create TABLE #kdqrexport2 (
	                          br128_1 VARCHAR(5),
	                          OrderDate VARCHAR(12),
							  br128_2 VARCHAR(5),
							  OrderNum varchar(20),
							  br128_3 VARCHAR(5),
							  ORDERQTY DECIMAL(18,4),
							  br128_4 VARCHAR(5),
							  Model   NVARCHAR(30),
							  Br128_5 VARCHAR(5),
							  PartNo VARCHAR(30),
							  Br128_6 VARCHAR(5),
							  ExtDescriptin NVARCHAR(200),
							  Specification NVARCHAR(200),
							  BomQty       DECIMAL(18,4),
							  Shipqty      DECIMAL(18,4),
							  Br128_7 VARCHAR(5),
							  QtyofCarton  DECIMAL(18,4),
							  BoxAmount INT,
							  Br128_8 VARCHAR(5),
							  BonNo  VARCHAR(10),
							  Parentbox VARCHAR(10),
							  Motherbox VARCHAR(10),
							  KDOrderinfoid VARCHAR(12),
							  Qrcode NVARCHAR(MAX))


	DECLARE @KDOrderInfoId VARCHAR(12)=''
	DECLARE @soname VARCHAR(12)=''
	DECLARE @Productid VARCHAR(12)=''
	DECLARE @CusterName NVARCHAR(80)=''
	DECLARE @mtcModel  NVARCHAR(50)=''
	DECLARE @orderdte  DATETIME=NULL
	DECLARE @boxcounter int =0
	DECLARE @PalletCount INT =0
	DECLARE @Country NVARCHAR(50)
	
	

	SELECT  @KDOrderInfoId = KDOrderInfoId,@ordername = OrderName,@CusterName = CustomerName,@orderdte = OrderDate,
	        @soname = SOName
       from KDOrderInfo WHERE kdorderinfoid = @i_pkid

    IF ISNULL(@KDOrderInfoId,'') =''
	begin
		set @I_ReturnMessage='ServerMessage:请选择订单号ID!'
		return -1
	END
	
	INSERT INTO #kdqrexport (br128_1, OrderDate, br128_2, OrderNum, br128_3, ORDERQTY, br128_4, Model, Br128_5, PartNo, 
	                          Br128_6, ExtDescriptin, Specification,
	                           BomQty, Shipqty, Br128_7, QtyofCarton, BoxAmount, Br128_8, BonNo, Qrcode,Kdboxinfoid)
	  SELECT '(95)',REPLACE(CONVERT(CHAR,a.OrderDate,111),'/','.'),'(242)',a.OrderName,'(30)',a.OrderQty,'(90)',
	          a.CustomerModel,'(240)',RTRIM(b.CustomerNumber),'(91)',b.EnglishDescription,'',b.BOMQtyRequired,b.QtyPack,
			  '(37)',a.PalletCounter,a.BoxCounter,'(243)',c.BoxNumber,
			  '(95)'+RTRIM(REPLACE(CONVERT(CHAR,a.OrderDate,111),'/','.'))+'(242)'+RTRIM(a.OrderName)+'(30)'+ RTRIM(convert(CHAR,cast(ORDERQTY AS FLOAT)))+'(90)'+
	         + RTRIM(a.CustomerModel)+'(240)'+ RTRIM(b.CustomerNumber)+'(91)'+RTRIM(b.EnglishDescription)+'(37)'+RTRIM(a.PalletCounter)+'(243)'+RTRIM(c.BoxNumber),c.KDBoxInfoId
	  FROM dbo.KDOrderInfo a WITH(NOLOCK)
     INNER JOIN  dbo.KDOrderItem b WITH(NOLOCK) ON b.KDOrderInfoId = a.KDOrderInfoId	 
	 INNER JOIN dbo.KDBoxItem f WITH(NOLOCK) ON f.KDOrderInfoId = b.KDOrderInfoId AND f.ProductId = b.ProductId
	 inner JOIN dbo.KDBoxInfo c WITH(NOLOCK) ON c.KDOrderInfoId = b.KDOrderInfoId AND c.KDBoxInfoId = f.KDBoxInfoId
	  WHERE a.KDOrderInfoId =  @KDOrderInfoId -- 'KDOI000003E7'  ---@i_pkid ORDER BY a.OrderName, a.CustomerModel,c.BoxNumber


	--  PRINT 'aaa'

	  UPDATE a SET a.BoxType = c.BoxType FROM #kdqrexport a	              
				  INNER  JOIN dbo.KDBoxInfo c ON c.KDBoxInfoId = a.Kdboxinfoid

    UPDATE a SET   Parentboxinfoid = b.ParentBoxInfoId   FROM #kdqrexport a
	  INNER JOIN  dbo.KDLoadBox b ON b.BoxInfoId = a.Kdboxinfoid AND b.KDOrderInfoId =@KDOrderInfoId  --'KDOI000003E7'
    
	 UPDATE a SET   a.Parentbox = b.BoxNumber   FROM #kdqrexport a
	    INNER JOIN dbo.KDBoxInfo b ON b.KDBoxInfoId = a.Parentboxinfoid

	UPDATE a SET   a.Motherbox = c.boxnumber   FROM #kdqrexport a
	  INNER JOIN  dbo.KDBoxInfo q ON q.BoxNumber = a.Parentbox AND q.KDOrderInfoId = @KDOrderInfoId
	  INNER JOIN  dbo.KDLoadBox b ON b.BoxInfoId = q.Kdboxinfoid AND b.KDOrderInfoId = @KDOrderInfoId 
	  INNER JOIN kdboxinfo c ON c.KDBoxInfoId = b.ParentBoxInfoId AND b.KDOrderInfoId = @KDOrderInfoId 

    UPDATE #kdqrexport SET Motherbox = Parentbox WHERE Motherbox IS NULL AND Parentbox IS NOT null
	UPDATE #kdqrexport SET Parentbox = bonno,Motherbox = bonno WHERE Motherbox IS NULL AND Parentbox IS null
    UPDATE #kdqrexport SET Motherbox = bonno WHERE Motherbox IS NULL 

	---SELECT * FROM #kdqrexport WHERE  Motherbox IS NULL 
	
	DECLARE @keycode VARCHAR(max)=''
	DECLARE @boxno VARCHAR(50)=''
	DECLARE @CustModel VARCHAR(50)=''

	  SET @keycode=''
	    UPDATE #kdqrexport SET @keycode = @keycode + RTRIM(br128_4)+RTRIM(Model) +RTRIM(Br128_5) 
		  + RTRIM(PartNo)+RTRIM(br128_6) + RTRIM(ExtDescriptin) + RTRIM(br128_7)+ RTRIM(convert(CHAR,cast(ORDERQTY AS FLOAT))) + RTRIM(br128_8)
		WHERE ExtDescriptin ='Key and IR/ LED assy'



	  UPDATE #kdqrexport SET Qrcode =@keycode + RTRIM(BonNo)
		  WHERE ExtDescriptin ='Key and IR/ LED assy'     --- 2020-01-14 以上完成了

	
	
	 -- 更新英文是ASSEMBLY ACCESSORIES PACKING 的记录

	-- print 'bb'

	  UPDATE #kdqrexport SET Qrcode =RTRIM(br128_1)+RTRIM(OrderDate)+RTRIM(br128_2)+ RTRIM(OrderNum)+RTRIM(br128_3) 
	           +RTRIM(convert(CHAR,cast(ORDERQTY AS FLOAT))) +RTRIM(br128_4)+RTRIM(Model) + RTRIM(Br128_5) +  RTRIM(PartNo)+RTRIM(Br128_6)
			   +RTRIM(Specification)+RTRIM(Br128_7)+RTRIM(CONVERT(CHAR,QtyofCarton))+RTRIM(Br128_8)+RTRIM(BonNo)
		  WHERE ExtDescriptin ='ASSEMBLY ACCESSORIES PACKING'


--- K箱拼箱
  
	SELECT BonNo,COUNT(1) AS boxqty INTO #Kboxno FROM #kdqrexport WHERE BoxType ='K' GROUP BY BonNo HAVING COUNT(1) >=2

  

      DECLARE mycursor CURSOR FOR SELECT bonNo FROM #kboxno 
	   open mycursor
		fetch next from mycursor 		into @boxno 
		while @@fetch_status=0  
		begin   

           SET @keycode=''
	      UPDATE a SET @keycode = @keycode + RTRIM(br128_4)+RTRIM(Model) +RTRIM(Br128_5) 
		  + RTRIM(PartNo)+RTRIM(br128_7) + RTRIM(convert(CHAR,cast(QtyofCarton AS FLOAT)))
		  FROM #kdqrexport a  WHERE a.BonNo = @boxno
		
	  -- PRINT @keycode
		
	    UPDATE #kdqrexport SET Qrcode =@keycode + RTRIM(BonNo)
		  WHERE BonNo = @boxno
		  fetch next from mycursor 		into @boxno 
	  END
     CLOSE mycursor
	 DEALLOCATE mycursor
	 DROP TABLE #kboxno
	 -- 取K 箱的数据
	  INSERT INTO #kdqrexport2 (br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox)
          SELECT  br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox FROM #kdqrexport 
									where ISNULL(BoxType,'') NOT IN('L','M')


	 --- L 箱的拼箱
	SELECT a.Parentboxinfoid,COUNT(1) AS qty INTO #Lboxno FROM #kdqrexport  a
	  INNER JOIN dbo.KDBoxInfo b ON b.KDBoxInfoId = a.Parentboxinfoid AND b.BoxType ='L'
	  GROUP BY a.Parentboxinfoid 
	DECLARE @parentboxid VARCHAR(12)=''
	DECLARE @qty INT =0
	DECLARE @partbox VARCHAR(50)=''
      DECLARE mycursor2 CURSOR FOR SELECT Parentboxinfoid,qty FROM #lboxno 
	  open mycursor2
	  FETCH next from mycursor2 		into @parentboxid,@qty
		while @@fetch_status=0  
		begin   
		 
		 SET @partbox =''
		 SELECT @partbox =  BoxNumber FROM dbo.KDBoxInfo WHERE KDBoxInfoId = @parentboxid

		 IF @qty >1
		 begin
		   ---(90)AN50U01(243)K/7(90)AN50U01(243)K/8(90)AN50U01(243)A2/2
		 SET @keycode=''
		 SET @CustModel=''
		 SET @boxno=''
		 DECLARE mycursor9 CURSOR FOR SELECT DISTINCT Model,BonNo FROM #kdqrexport WHERE Parentboxinfoid = @parentboxid
	     open mycursor9
	     FETCH next from mycursor9 		into @CustModel,@boxno
	 	 WHILE @@fetch_status=0  
		 BEGIN  	  
           SET @keycode = @keycode + '(90)'+RTRIM(@CustModel) +'(243)' + RTRIM(@boxno)
		   FETCH next from mycursor9 		into @CustModel,@boxno
		 end
		 
		 CLOSE mycursor9
		 DEALLOCATE mycursor9
		
	    --  UPDATE #kdqrexport  WHERE Parentboxinfoid = 'KDBI0001QWRD'

		  INSERT INTO #kdqrexport2 (br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox)
          SELECT TOP 1 br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,'',Br128_6,'',
                                    '',0,0,Br128_7,0,
                                    0,Br128_8,@partbox,Qrcode,Parentbox,Motherbox FROM #kdqrexport
									 WHERE Parentboxinfoid = @parentboxid 


		END
		ELSE
        begin
         INSERT INTO #kdqrexport2 (br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox)
          SELECT TOP 1 br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,@partbox,Qrcode,Parentbox,Motherbox FROM #kdqrexport 
									WHERE Parentboxinfoid = @parentboxid AND BonNo = @boxno
	   end

    FETCH next from mycursor2 		into @parentboxid,@qty
   END
     CLOSE mycursor2
	 DEALLOCATE mycursor2
	 DROP TABLE #Lboxno

	 --print 'ccc'
	--- M 拼箱
	SELECT a.Parentboxinfoid,COUNT(1) AS qty INTO #Mboxno FROM #kdqrexport  a
	  INNER JOIN dbo.KDBoxInfo b ON b.KDBoxInfoId = a.Parentboxinfoid AND b.BoxType ='M'
	  GROUP BY a.Parentboxinfoid 

	 DECLARE mycursor3 CURSOR FOR SELECT Parentboxinfoid,qty FROM #Mboxno 
	  open mycursor3
	  FETCH next from mycursor3 		into @parentboxid,@qty
		while @@fetch_status=0  
		begin   
		 
		 SET @boxno =''
		 SELECT @boxno =  BoxNumber FROM dbo.KDBoxInfo WHERE KDBoxInfoId = @parentboxid

		 IF @qty >1
		 begin
		   
           SET @keycode=''
	       UPDATE a SET a.QRCode= RTRIM(br128_1) + RTRIM(OrderDate)+RTRIM(br128_2)+RTRIM(ordernum) + RTRIM(br128_8) +RTRIM(@boxno)
		    +RTRIM(Br128_4) + RTRIM(Model)+RTRIM(br128_5) + RTRIM(PartNo)+ RTRIM(br128_6)+ RTRIM(ExtDescriptin)
			+RTRIM(br128_3)+ RTRIM(convert(CHAR,cast(ORDERQTY AS FLOAT)))+RTRIM(br128_7)+RTRIM(convert(CHAR,cast(a.QtyofCarton AS FLOAT)))
		   FROM #kdqrexport a  WHERE Parentboxinfoid = @parentboxid
		
	   --   UPDATE #kdqrexport SET Qrcode =@keycode + RTRIM(BonNo)
		--  WHERE BonNo = @boxno

		  INSERT INTO #kdqrexport2 (br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox)
          SELECT  br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox FROM #kdqrexport WHERE Parentboxinfoid = @parentboxid


		END
		ELSE
        begin
         INSERT INTO #kdqrexport2 (br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox)
          SELECT  br128_1,OrderDate,br128_2,OrderNum,br128_3,ORDERQTY,
                                    br128_4,Model,Br128_5,PartNo,Br128_6,ExtDescriptin,
                                    Specification,BomQty,Shipqty,Br128_7,QtyofCarton,
                                    BoxAmount,Br128_8,BonNo,Qrcode,Parentbox,Motherbox FROM #kdqrexport WHERE Parentboxinfoid = @parentboxid
	   end

    FETCH next from mycursor3 		into @parentboxid,@qty
   END
     CLOSE mycursor3
	 DEALLOCATE mycursor3
	 DROP TABLE #Mboxno


	 --print 'dd'


   IF @I_Sender ='ExportPicklistToexcel'
   begin
	SELECT br128_1 AS 'Code128(95)',OrderDate AS '生产时间',br128_2 AS 'Code128(242)',OrderNum AS '客户PO号码',br128_3 'Code128(30)',ORDERQTY AS '下单数量',
                                    br128_4 AS 'Code128(90)',Model AS '客户机型',Br128_5 AS 'Code128(240)',PartNo AS '物品料号',Br128_6 AS 'Code128(91)',
									ExtDescriptin AS '物料名称',Specification AS '料号规格',BomQty AS '用量',Shipqty AS '出货数量',Br128_7 AS 'Code128(37)',
									QtyofCarton AS '装箱数量',BoxAmount AS '总箱数',Br128_8 AS 'Code128(243)',BonNo AS '箱号',Parentbox AS '中箱号码',
									Motherbox AS '外箱号码',Qrcode FROM #kdqrexport2 ORDER BY Motherbox,Parentbox
   END
   ELSE
   BEGIN
   SELECT OrderNum AS OrderName,Model AS Model,a.PartNo AS Productname,PartNo,Specification,
          RTRIM(CONVERT(CHAR,CAST(b.BoxLength AS FLOAT))) + '*' +RTRIM(CONVERT(CHAR,CAST(b.BoxLength AS FLOAT)))+'*'
		  + RTRIM(CONVERT(CHAR,CAST(b.BoxHeight AS FLOAT))),a.BonNo AS CartonNo,a.OrderDate AS date,CAST(a.ORDERQTY AS FLOAT) AS qty,
		  b.NetWeight,b.GrossWeight AS Weight		  
		   FROM #kdqrexport2 a
       INNER JOIN dbo.KDBoxInfo b ON b.BoxNumber = a.BonNo and  b.kdorderinfoid = @KDOrderInfoId
   end

    DROP TABLE #kdqrexport
	DROP TABLE #kdqrexport2

	RETURN 0
END

