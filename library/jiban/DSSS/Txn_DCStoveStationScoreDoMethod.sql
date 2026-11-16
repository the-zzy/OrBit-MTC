
-- =============================================
-- Author:		<MTC mhy>
-- Create date: <2019.06.26>
-- Updat  date: <2019.08.19> 
-- Description:	<数据复制>  DC StoveStationScoreEntry

--CreateDate,Workcentername,ShiftName,Moname,CurrRsultQty,MoveOperator,RECOperator
-- =============================================
CREATE PROCEDURE [dbo].[Txn_DCStoveStationScoreDoMethod]
    @I_Sender NVARCHAR(200) = '' , --客户端执行按钮
    @I_ReturnMessage NVARCHAR(MAX) = '' OUTPUT ,  --返回的信息,支持多语言
    @I_ExceptionFieldName NVARCHAR(100) = '' OUTPUT , --向客户端报告引起冲突的字段
    @I_LanguageId CHAR(1) = '1' ,				--客户端传入的语言ID
    @I_PlugInCommand VARCHAR(5) = '' ,		--插件命令
    @I_OrBitUserId CHAR(12) = '' ,			--用户ID
    @I_OrBitUserName NVARCHAR(100) = '' ,	--用户名	
    @I_ResourceId CHAR(12) = '' ,		--资源ID(如果资源不在资源清单中，那么它将是空的)
    @I_ResourceName NVARCHAR(100) = '' ,	--资源名
    @I_PKId CHAR(12) = '' ,				--主键
    @I_SourcePKId CHAR(12) = '' ,			--执行拷贝时传入的源主键  
    @I_ParentPKId CHAR(12) = '' ,			--父级主键
    @I_Parameter NVARCHAR(100) = '' , 		--插件参数	
    @CreateDate DATETIME = NULL ,
    @MovetoDip INT = 0 ,				--转板数量，对应到数据表的TransPlates列
    @Workcentername VARCHAR(30) = '' ,
    @ShiftName NVARCHAR(30) = '' ,
    @Moname NVARCHAR(50) = '' ,         --订单号
    @CurrRsultQty INT = 0 ,
    @MoveOperator VARCHAR(30) = '' ,          --操作员
    @RECOperator VARCHAR(30) = '' ,             --产品批号
    @ProductName VARCHAR(50) = '' ,
	@Side NVARCHAR(10) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
    SET NOCOUNT ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    DECLARE @return_value INT;
    DECLARE @TxnCode VARCHAR(10);
    DECLARE @Date DATETIME;

	IF ISNULL(@Moname, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'Servermessage:请输入生产的工单！';
            SET @I_ExceptionFieldName = 'Moname';
            RETURN -1;
        END;

    IF NOT EXISTS ( SELECT TOP 1
                            1
                    FROM    MO
                    WHERE   RIGHT(MOName, 10) = RIGHT(@Moname, 10) )
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入有效的生产的工单！';
        SET @I_ExceptionFieldName = 'Moname';
        RETURN -1;
    END;

    IF ISNULL(@Workcentername, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入生产线体！';
        RETURN -1;
    END;
    IF ISNULL(@ShiftName, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入作业班次！';
        RETURN -1;
    END;

	IF ISNULL(@Side, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入面别！';
        RETURN -1;
    END;


    --IF @CurrRsultQty = 0
    --BEGIN
    --    SET @I_ReturnMessage = 'Servermessage:请输入产实绩！';
    --    RETURN -1;
    --END;
  
    IF ISNULL(@MoveOperator, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入交接人员工号！';
        RETURN -1;
    END;
    IF ISNULL(@RECOperator, '') = ''
    BEGIN
        SET @I_ReturnMessage = 'Servermessage:请输入接收人工号！';
        RETURN -1;
    END;
    


    IF @I_Sender = 'ShowMessage1'
    BEGIN
        SELECT  GETDATE() AS CreateDate; 
        RETURN 0;
    END;

    IF @I_Sender = 'MonameShow'	 --不知什么原因不生效
    BEGIN
        IF ISNULL(@Moname, '') = ''
        BEGIN
            SET @I_ReturnMessage = 'Servermessage:请输入生产的工单！';
            SET @I_ExceptionFieldName = 'Moname';
            RETURN -1;
        END;

        IF NOT EXISTS ( SELECT TOP 1
                                1
                        FROM    MO
                        WHERE   RIGHT(MOName, 10) = RIGHT(@Moname, 10) )
        BEGIN
            SET @I_ReturnMessage = 'Servermessage:请输入有效的生产的工单！';
            SET @I_ExceptionFieldName = 'Moname';
            RETURN -1;
        END;
       
        SELECT  b.ProductName, a.MOQtyRequired AS moqty, a.MOQtyRequired - a.MOQtyDone AS RemainQty, a.MOQtyDone,
                a.SOName
        FROM    MO a
        INNER JOIN ProductRoot b ON b.DefaultProductId = a.ProductId
        WHERE   RIGHT(a.MOName, 10) = RIGHT(@Moname, 10);
        RETURN 0;
    END;
    
	

    --IF EXISTS ( SELECT TOP 1
    --                    1
    --            FROM    dbo.DailyResult
    --            WHERE   CONVERT(CHAR, CreateDate, 23) = CONVERT(CHAR, @CreateDate, 23) 
				--AND Moname = RIGHT('0000' + @Moname,12) AND WorkCenterName = @Workcentername )
    --BEGIN
    --    SET @I_ReturnMessage = 'Servermessage:已做过登记，不能重复登记！';
    --    SET @I_ExceptionFieldName = 'Moname';
    --    RETURN -1;
    --END;

	--add by zwb
	DECLARE @MoAmount INT,@CumQty INT,@TransDipQty INT --工单数量，累计完成数量，累计转板数量   
	SELECT @MoAmount =( MOQtyRequired - MOQtyDone )
	FROM dbo.MO
	WHERE MOName = RIGHT('0000' + @Moname, 12);

	--转板数量大于工单数量时
	IF @MoAmount <@MovetoDip
	BEGIN
	   SET @I_ReturnMessage = 'Servermessage:转板数量不能大于工单数量，请重新输入！';
	   RETURN -1;
	END

	--- update zheng wb  2023.02.20 AB面的生产数量按照各自的数量计算，不相加算总和
	--未完工数量为0，当班生产数量变成0，
	--使用工单数量和累计完成数量是否相等，或者不让他插入，弹出提示数量已完工
	--转板累计数量等于工单数量 并且 累计完成数量等于工单数量
	SELECT @CumQty = SUM(CurrRsultQty),@TransDipQty = SUM(TransPlates) 
	FROM DCStoveStationHistory
	WHERE MOName = RIGHT('0000' + @Moname, 12) AND Side = @Side

	IF @MoAmount=@CumQty AND @MoAmount=@TransDipQty
	BEGIN		
		SELECT @CurrRsultQty=0,@TransDipQty = 0 ;
		SET @I_ReturnMessage = 'Servermessage:该面别的工单数量已完成'
	    RETURN -1
	END

	IF @MoAmount=@CumQty AND @CurrRsultQty>0
	BEGIN
		SELECT @CurrRsultQty=0
		SET @I_ReturnMessage = 'Servermessage:该累计完成数量不能大于工单数量'
	    RETURN -1
	END

	IF @MoAmount=@TransDipQty AND @MovetoDip>0
	BEGIN
		
		SELECT @MovetoDip=0;
		SET @I_ReturnMessage = 'Servermessage:该累计转板数量不能大于工单数量'
	    RETURN -1
	END

	--转板数量和当班生产数量填入的值是否正确
	--累计完成数量= SUM(CurrRsultQty)，输入的值要小于工单数量-累计完成数量
	IF @CurrRsultQty>(@MoAmount - @CumQty)
	BEGIN
		SET @I_ReturnMessage = 'Servermessage:当班生产数量有误！，该面别的工单生产剩余余数:'+CONVERT(CHAR(5),(@MoAmount - @CumQty)) 
	    RETURN -1
	END 

	--累计转板数量 = @TransDipQty SUM(TransPlates)
	IF @MovetoDip>(@MoAmount - @TransDipQty)
	BEGIN
		SET @I_ReturnMessage = 'Servermessage:转板数量有误！，该面别的剩余转板数量:'+CONVERT(CHAR(5),(@MoAmount - @TransDipQty))
	    RETURN -1;
	END 
    
	

    DECLARE @DailyResultid VARCHAR(12)= '';
	

    set @CreateDate = GETDATE()
    EXEC dbo.SysGetObjectPKId
        @ObjectId = '' , -- char(12)
        @ObjectName = N'DailyResult' , -- nvarchar(100)
        @PKID = @DailyResultid OUTPUT; -- char(12)
    INSERT  INTO dbo.DailyResult ( DailyResultid, CreateDate, WorkCenterName, ShiftName, Moname, Soname, CurrRsultQty,
                                   MoveOperator, RECOperator, CreateUserid, TransPlates,Side )
            SELECT TOP 1
                    @DailyResultid, @CreateDate, @Workcentername, @ShiftName, a.MOName, a.SOName, @CurrRsultQty,
                    @MoveOperator, @RECOperator, @I_OrBitUserId, @MovetoDip,@Side
            FROM    MO a
            INNER JOIN ProductRoot b ON b.DefaultProductId = a.ProductId
            WHERE   a.MOName = RIGHT('0000' + @Moname, 12);

	


	---最后输出表格
    DECLARE @MOqty INT ,
        @MOdonqty INT ,
        @RemainQty INT ,
        @MovetoDipEntry INT,
		@ItemCount INT =0 

		
	--临时表一,获取不需要聚合的字段
    SELECT  DailyResult.CreateDate, WorkCenterName, ShiftName, DailyResult.Moname, DailyResult.Soname, ProductName,
            CurrRsultQty, MOQtyDone, ( MOQtyRequired - MOQtyDone ) AS MOqty, TransPlates 转板数量, MoveOperator,
            RECOperator, DailyResult.CreateUserid,DailyResult.Side
    INTO    #tempt1
    FROM    dbo.DailyResult
    INNER JOIN dbo.MO ON MO.MOName = DailyResult.Moname
    INNER JOIN ProductRoot ON ProductRoot.DefaultProductId = dbo.MO.ProductId;

	--临时表二，获取需要聚合的字段并分组
    SELECT  DailyResult.Moname,Side, SUM(DailyResult.TransPlates) AS MovetoDipQty,SUM(CurrRsultQty) AS MOdonqty
    INTO    #tempt2
    FROM    dbo.DailyResult
    INNER JOIN dbo.MO ON MO.MOName = DailyResult.Moname
    INNER JOIN ProductRoot ON ProductRoot.DefaultProductId = dbo.MO.ProductId 
    GROUP BY DailyResult.Moname,Side;

	---获取工单下的AB面累计完成数量
	--SELECT  @ItemCount = SUM(CurrRsultQty)
 --   FROM    dbo.DailyResult
 --   INNER JOIN dbo.MO ON MO.MOName = DailyResult.Moname
 --   INNER JOIN ProductRoot ON ProductRoot.DefaultProductId = dbo.MO.ProductId
	--WHERE  DailyResult.Moname = RIGHT('0000' + @Moname, 12)
 --   GROUP BY DailyResult.Moname;

	 ---查询是否创建了存放登记历史数据表，没有则创建表
    IF NOT EXISTS ( SELECT  1
                    FROM    sys.tables
                    WHERE   name = 'DCStoveStationHistory' )
    BEGIN
        CREATE TABLE DCStoveStationHistory
            (
              CreateDate DATETIME ,
              WorkCenterName VARCHAR(30) ,
              ShiftName VARCHAR(20) ,
              Moname VARCHAR(30) ,
              Soname VARCHAR(30) ,
              ProductName VARCHAR(30) ,
			  Side NVARCHAR(10) ,
              MOqty INT ,
              CurrRsultQty INT ,
              MOdonqty INT ,
              RemainQty INT ,
              TransPlates INT ,
              MovetoDipQty INT ,
              MoveOperator VARCHAR(20) ,
              RECOperator VARCHAR(20),
			  CreateUserid VARCHAR(12)
            );
    END;

	---将查询的结果集插入登记历史数据表
	INSERT INTO dbo.DCStoveStationHistory 
    SELECT TOP 1  --拼接
            CreateDate, #tempt1.WorkCenterName, #tempt1.ShiftName, #tempt1.Moname, #tempt1.Soname, ProductName,
			#tempt1.Side, MOqty,CONVERT(INT, #tempt1.CurrRsultQty) AS CurrRsultQty, CONVERT(INT, MOdonqty) AS MOdonqty,
            (MOqty-#tempt2.MOdonqty) AS RemainQty, 转板数量, MovetoDipQty,#tempt1.MoveOperator, #tempt1.RECOperator,
			 #tempt1.CreateUserid
    FROM #tempt1 
    LEFT JOIN #tempt2 ON #tempt2.Moname = #tempt1.Moname AND #tempt1.Side = #tempt2.Side
    WHERE  #tempt1.Moname = RIGHT('0000' + @Moname, 12) AND #tempt1.Side = @Side
	ORDER BY CreateDate DESC

	---查询结果返回到info表中
	SELECT CreateDate,WorkCenterName,ShiftName,Moname,Soname,ProductName,Side,MOqty,CurrRsultQty,
			MOdonqty,RemainQty,TransPlates 转板数量,MovetoDipQty,MoveOperator,RECOperator,CreateUserid, MOqty-MovetoDipQty AS MoveRemindQty
	FROM DCStoveStationHistory
	WHERE Moname = RIGHT('0000' + @Moname, 12)
	ORDER BY CreateDate DESC 
	 


	--给显示不出来的字段直接赋值
    SELECT  @MOqty = #tempt1.MOqty, @RemainQty = (MOqty-MOdonqty), @MovetoDipEntry = MovetoDipQty,
            @MOdonqty = CONVERT(INT, MOdonqty)
    FROM    #tempt1
    LEFT JOIN #tempt2 ON #tempt2.Moname = #tempt1.Moname 
    WHERE   #tempt1.Moname = RIGHT('0000' + @Moname, 12);
		  
    --SELECT  *
    --FROM    DailyResult
    --WHERE   CreateDate >= CONVERT(CHAR, GETDATE(), 23);
    SELECT  '' AS CreateDate,'' AS Workcentername,''AS ShiftName,'' AS Moname,''AS Side, 
			 0 AS CurrRsultQty,''AS Soname,''AS Productname,0 AS Moqty,0 AS Modonqty,
			 0 AS RemainQty,0 AS MovetoDip,0 AS MovetoDipQty,'' AS MoveOperator,'' AS RECOperator, 'OKFACE.PNG' AS img 
			--@MOqty AS MOqty,@RemainQty AS RemainQty, @MovetoDipEntry AS MovetoDipQty, @MOdonqty AS Modonqty
    SET @I_ReturnMessage = 'Servermessage:登记成功';


    RETURN 0;

END;


--SELECT * FROM dbo.DCStoveStationScan ORDER BY CreateDate DESC  
--SELECT * FROM mo WHERE moid  ='MOD10000BY3M'






